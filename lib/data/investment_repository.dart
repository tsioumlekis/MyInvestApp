import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/holding.dart';
import '../utils/wealth.dart';

/// Επενδύσεις ενός χρήστη στο Firestore:
/// `users/{uid}/holdings/{id}` και `users/{uid}/trades/{id}`.
class InvestmentRepository {
  InvestmentRepository(String uid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _user = (firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(uid);

  final FirebaseFirestore _db;
  final DocumentReference<Map<String, dynamic>> _user;

  CollectionReference<Map<String, dynamic>> get _holdings =>
      _user.collection('holdings');
  CollectionReference<Map<String, dynamic>> get _trades =>
      _user.collection('trades');

  /// Όλες οι θέσεις, με τις συναλλαγές τους, ενημερωμένες σε πραγματικό χρόνο.
  Stream<List<Position>> watchPositions() {
    late final StreamController<List<Position>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? holdingsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? tradesSub;
    List<Holding>? holdings;
    List<Trade>? trades;

    void emit() {
      if (holdings == null || trades == null) return;
      final byHolding = <String, List<Trade>>{};
      for (final t in trades!) {
        byHolding.putIfAbsent(t.holdingId, () => []).add(t);
      }
      controller.add([
        for (final h in holdings!) Position(h, byHolding[h.id] ?? const []),
      ]);
    }

    controller = StreamController<List<Position>>(
      onListen: () {
        holdingsSub = _holdings.snapshots().listen((s) {
          holdings = [for (final d in s.docs) Holding.fromMap(d.id, d.data())];
          emit();
        }, onError: controller.addError);
        tradesSub = _trades.snapshots().listen((s) {
          trades = [for (final d in s.docs) Trade.fromMap(d.id, d.data())];
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await holdingsSub?.cancel();
        await tradesSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Νέα θέση μαζί με την πρώτη αγορά.
  Future<void> addHolding({
    required String accountId,
    required String symbol,
    required String name,
    required AssetType assetType,
    required String currency,
    required String exchange,
    required DateTime date,
    required double quantity,
    required double price,
    required double fees,
  }) {
    final holdingRef = _holdings.doc();
    final tradeRef = _trades.doc();
    final holding = Holding(
      id: holdingRef.id,
      accountId: accountId,
      symbol: symbol,
      name: name,
      assetType: assetType,
      currency: currency,
      exchange: exchange,
      currentPrice: price,
      priceUpdatedAt: DateTime.now(),
    );
    final trade = Trade(
      id: tradeRef.id,
      holdingId: holdingRef.id,
      side: TradeSide.buy,
      date: date,
      quantity: quantity,
      price: price,
      fees: fees,
    );
    return (_db.batch()
          ..set(holdingRef, holding.toMap())
          ..set(tradeRef, trade.toMap()))
        .commit();
  }

  Future<void> saveHolding(Holding holding) =>
      _holdings.doc(holding.id).set(holding.toMap());

  Future<void> updatePrice(Holding holding, double price) {
    return saveHolding(holding.copyWith(
      currentPrice: price,
      priceUpdatedAt: DateTime.now(),
    ));
  }

  /// Ενημερώνει πολλές τιμές μαζί (holdingId -> τιμή).
  Future<void> updatePrices(Map<String, double> prices) {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    prices.forEach((holdingId, price) {
      batch.update(_holdings.doc(holdingId),
          {'currentPrice': price, 'priceUpdatedAt': now});
    });
    return batch.commit();
  }

  /// Ρυθμίσεις χρήστη (έγγραφο `users/{uid}`).
  Stream<Map<String, dynamic>> watchSettings() =>
      _user.snapshots().map((s) => s.data() ?? const {});

  CollectionReference<Map<String, dynamic>> get _snapshots =>
      _user.collection('snapshots');

  /// Ημερήσια στιγμιότυπα περιουσίας (id = yyyy-MM-dd), από το παλαιότερο.
  Stream<List<WealthSnapshot>> watchSnapshots() => _snapshots
      .orderBy(FieldPath.documentId)
      .snapshots()
      .map((s) =>
          [for (final d in s.docs) WealthSnapshot.fromMap(d.id, d.data())]);

  Future<void> saveSnapshot(String day, Map<String, dynamic> data) =>
      _snapshots.doc(day).set(data);

  Future<void> saveSetting(String field, Object value) =>
      _user.set({field: value}, SetOptions(merge: true));

  /// Διαγράφει τη θέση και όλες τις συναλλαγές της.
  Future<void> deleteHolding(Position position) {
    final batch = _db.batch()..delete(_holdings.doc(position.holding.id));
    for (final t in position.trades) {
      batch.delete(_trades.doc(t.id));
    }
    return batch.commit();
  }

  Future<void> addTrade({
    required String holdingId,
    required TradeSide side,
    required DateTime date,
    required double quantity,
    required double price,
    required double fees,
    String note = '',
  }) {
    final ref = _trades.doc();
    return ref.set(Trade(
      id: ref.id,
      holdingId: holdingId,
      side: side,
      date: date,
      quantity: quantity,
      price: price,
      fees: fees,
      note: note,
    ).toMap());
  }

  Future<void> deleteTrade(String tradeId) => _trades.doc(tradeId).delete();
}
