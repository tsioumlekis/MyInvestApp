import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/holding.dart';
import '../utils/privacy.dart';
import '../utils/wealth.dart';
import 'account_repository.dart';
import 'fx_service.dart';
import 'investment_repository.dart';
import 'price_service.dart';

/// Κρατά τα τρέχοντα δεδομένα του χρήστη (λογαριασμοί, θέσεις, ισοτιμίες)
/// και ειδοποιεί τις οθόνες όταν αλλάζουν στο Firestore.
class FinanceStore extends ChangeNotifier {
  FinanceStore(String uid)
      : accountsRepo = AccountRepository(uid),
        investmentsRepo = InvestmentRepository(uid) {
    _subs = [
      accountsRepo.watchAll().listen((v) {
        _accounts = v;
        notifyListeners();
      }, onError: _onError),
      investmentsRepo.watchPositions().listen((v) {
        final firstLoad = _positions == null;
        _positions = v;
        notifyListeners();
        if (firstLoad) _autoRefreshPrices();
      }, onError: _onError),
      investmentsRepo.watchSettings().listen((v) {
        final firstLoad = !_settingsLoaded;
        _settingsLoaded = true;
        _twelveDataKey = v['twelveDataKey'] as String?;
        _fx = FxRates.fromMap(v['fx']);
        _fxFetchedAt = DateTime.tryParse('${(v['fx'] as Map?)?['fetchedAt']}');
        notifyListeners();
        if (firstLoad) _refreshFxIfStale();
      }, onError: (Object e) => debugPrint('Settings: $e')),
      investmentsRepo.watchSnapshots().listen((v) {
        _snapshots = v;
        notifyListeners();
      }, onError: (Object e) => debugPrint('Snapshots: $e')),
    ];
    // Όταν αλλάζει η απόκρυψη ποσών, ξανασχεδιάζονται όλες οι οθόνες.
    hideAmounts.addListener(notifyListeners);
  }

  // ------------------------------------------------- Ιστορικό περιουσίας

  List<WealthSnapshot> _snapshots = const [];

  /// Ημερήσια στιγμιότυπα καθαρής περιουσίας (σε ευρώ), από το παλαιότερο.
  List<WealthSnapshot> get snapshots => _snapshots;

  /// Η τρέχουσα περιουσία σε ευρώ (null αν λείπει ισοτιμία).
  WealthBreakdown? get wealth =>
      WealthBreakdown.compute(accounts, positions, _fx);

  Timer? _snapshotTimer;
  String? _lastSnapshot;

  /// Αποθηκεύει (με καθυστέρηση) το σημερινό στιγμιότυπο όταν αλλάζουν τα
  /// δεδομένα. Μία εγγραφή ανά ημέρα, που ενημερώνεται μέσα στη μέρα.
  void _scheduleSnapshot() {
    if (isLoading || _error != null) return;
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(seconds: 3), () async {
      final w = wealth;
      if (w == null || _disposed) return;
      final data = w.toMap();
      final now = DateTime.now();
      final day = '${now.year}-${now.month.toString().padLeft(2, '0')}'
          '-${now.day.toString().padLeft(2, '0')}';
      final key = '$day $data';
      if (key == _lastSnapshot) return;
      _lastSnapshot = key;
      try {
        await investmentsRepo.saveSnapshot(day, data);
      } catch (e) {
        debugPrint('Snapshot save failed: $e');
      }
    });
  }

  final AccountRepository accountsRepo;
  final InvestmentRepository investmentsRepo;
  late final List<StreamSubscription<Object?>> _subs;

  List<Account>? _accounts;
  List<Position>? _positions;
  Object? _error;

  bool get isLoading =>
      _error == null && (_accounts == null || _positions == null);
  Object? get error => _error;
  List<Account> get accounts => _accounts ?? const [];
  List<Position> get positions => _positions ?? const [];

  Account? accountById(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Position? positionById(String holdingId) {
    for (final p in positions) {
      if (p.holding.id == holdingId) return p;
    }
    return null;
  }

  // ------------------------------------------------------------ Ρυθμίσεις

  bool _settingsLoaded = false;
  String? _twelveDataKey;
  String? get twelveDataKey => _twelveDataKey;

  Future<void> saveTwelveDataKey(String key) =>
      investmentsRepo.saveSetting('twelveDataKey', key.trim());

  // ------------------------------------------------------------ Ισοτιμίες

  FxRates? _fx;
  DateTime? _fxFetchedAt;

  /// Ισοτιμίες ΕΚΤ (null μέχρι να φορτωθούν την πρώτη φορά).
  FxRates? get fx => _fx;

  Future<void> refreshFx() async {
    final rates = await FxService().fetch();
    await investmentsRepo.saveSetting('fx', {
      ...rates.toMap(),
      'fetchedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _refreshFxIfStale() async {
    final stale = DateTime.now().subtract(const Duration(hours: 6));
    if (_fx != null && _fxFetchedAt != null && _fxFetchedAt!.isAfter(stale)) {
      return;
    }
    try {
      await refreshFx();
    } catch (e) {
      debugPrint('FX refresh failed: $e');
    }
  }

  // ---------------------------------------------------------------- Τιμές

  bool _refreshing = false;
  bool get isRefreshingPrices => _refreshing;

  /// Αποτέλεσμα της τελευταίας ανανέωσης τιμών σε αυτή τη συνεδρία
  /// (και της αυτόματης), για να φαίνεται αν κάτι δεν βρέθηκε.
  PriceResult? _lastPriceResult;
  PriceResult? get lastPriceResult => _lastPriceResult;

  /// Φέρνει τρέχουσες τιμές για όλες τις ανοιχτές θέσεις (και ισοτιμίες).
  Future<PriceResult> refreshPrices() async {
    if (_refreshing) return PriceResult(const {}, const []);
    _refreshing = true;
    notifyListeners();
    try {
      final holdings = [
        for (final p in positions)
          if (p.isOpen) p.holding,
      ];
      final (result, _) = await (
        PriceService(twelveDataKey: _twelveDataKey, fx: _fx).fetch(holdings),
        _refreshFxIfStale(),
      ).wait;
      if (result.prices.isNotEmpty) {
        await investmentsRepo.updatePrices(result.prices);
      }
      _lastPriceResult = result;
      return result;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  static const _refreshEvery = Duration(minutes: 5);
  Timer? _priceTimer;

  /// Ανανέωση στο άνοιγμα της εφαρμογής (αν οι τιμές είναι παλιές) και μετά
  /// κάθε 5 λεπτά όσο η εφαρμογή είναι ανοιχτή.
  Future<void> _autoRefreshPrices() async {
    _priceTimer ??= Timer.periodic(_refreshEvery, (_) => _autoRefreshPrices());
    // Λίγο μικρότερο όριο από το διάστημα, για να μη χάνεται οριακά ο γύρος.
    final stale =
        DateTime.now().subtract(_refreshEvery - const Duration(seconds: 30));
    final needsRefresh = positions
        .any((p) => p.isOpen && p.holding.priceUpdatedAt.isBefore(stale));
    if (!needsRefresh) return;
    // Μικρή αναμονή ώστε να έχει φορτώσει και το κλειδί από τις ρυθμίσεις.
    await Future<void>.delayed(const Duration(seconds: 1));
    try {
      await refreshPrices();
    } catch (e) {
      debugPrint('Auto price refresh failed: $e');
    }
  }

  // -------------------------------------------------------------- Κύκλος ζωής

  void _onError(Object error) {
    _error = error;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
    _scheduleSnapshot();
  }

  @override
  void dispose() {
    _disposed = true;
    hideAmounts.removeListener(notifyListeners);
    _snapshotTimer?.cancel();
    _priceTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
