import '../data/fx_service.dart';
import '../models/account.dart';
import '../models/holding.dart';

/// Περιουσία σε ευρώ, ανά κατηγορία.
class WealthBreakdown {
  WealthBreakdown(this.byType, {required this.converted});

  /// Ποσά σε ευρώ ανά κατηγορία λογαριασμού. Οι επενδύσεις περιλαμβάνουν
  /// και την αξία των ανοιχτών θέσεων.
  final Map<AccountType, double> byType;

  /// True αν μετατράπηκαν ποσά από άλλο νόμισμα.
  final bool converted;

  double get total => byType.values.fold(0, (a, b) => a + b);

  /// Υπολογίζει την περιουσία. Επιστρέφει null αν λείπει κάποια ισοτιμία.
  static WealthBreakdown? compute(
      List<Account> accounts, List<Position> positions, FxRates? fx) {
    final byType = {for (final t in AccountType.values) t: 0.0};
    var converted = false;

    double? eur(double amount, String currency) {
      if (currency != 'EUR') converted = true;
      if (currency == 'EUR') return amount;
      return fx?.toEur(amount, currency);
    }

    for (final a in accounts) {
      final v = eur(a.balance, a.currency);
      if (v == null) return null;
      byType[a.type] = byType[a.type]! + v;
    }
    for (final p in positions.where((p) => p.isOpen)) {
      final v = eur(p.marketValue, p.holding.currency);
      if (v == null) return null;
      byType[AccountType.investment] = byType[AccountType.investment]! + v;
    }
    return WealthBreakdown(byType, converted: converted);
  }

  Map<String, dynamic> toMap() => {
        for (final e in byType.entries) e.key.name: _round(e.value),
        'total': _round(total),
      };

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

/// Στιγμιότυπο καθαρής περιουσίας για μία ημέρα.
class WealthSnapshot {
  WealthSnapshot(this.date, this.total);

  final DateTime date;
  final double total;

  factory WealthSnapshot.fromMap(String id, Map<String, dynamic> map) =>
      WealthSnapshot(
        DateTime.tryParse(id) ?? DateTime.now(),
        (map['total'] as num?)?.toDouble() ?? 0,
      );
}
