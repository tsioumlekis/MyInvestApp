import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/models/holding.dart';

Holding _holding({double price = 0}) => Holding(
      id: 'h',
      accountId: 'a',
      symbol: 'TEST',
      name: '',
      assetType: AssetType.stock,
      currency: 'EUR',
      currentPrice: price,
      priceUpdatedAt: DateTime(2026),
    );

Trade _trade(TradeSide side, int day, double qty, double price,
        {double fees = 0}) =>
    Trade(
      id: '$side$day',
      holdingId: 'h',
      side: side,
      date: DateTime(2026, 1, day),
      quantity: qty,
      price: price,
      fees: fees,
    );

void main() {
  test('μέση τιμή με προμήθειες', () {
    final p = Position(_holding(price: 12), [
      _trade(TradeSide.buy, 1, 10, 10, fees: 1),
      _trade(TradeSide.buy, 2, 10, 11, fees: 1),
    ]);
    expect(p.quantity, 20);
    expect(p.costBasis, closeTo(212, 1e-9));
    expect(p.avgPrice, closeTo(10.6, 1e-9));
    expect(p.marketValue, closeTo(240, 1e-9));
    expect(p.unrealizedPnl, closeTo(28, 1e-9));
    expect(p.totalFees, 2);
  });

  test('μερική πώληση: πραγματοποιημένο κέρδος με μέσο κόστος', () {
    final p = Position(_holding(price: 15), [
      _trade(TradeSide.buy, 1, 10, 10),
      _trade(TradeSide.sell, 2, 4, 15, fees: 2),
    ]);
    expect(p.quantity, 6);
    expect(p.costBasis, closeTo(60, 1e-9));
    expect(p.realizedPnl, closeTo(4 * 15 - 2 - 40, 1e-9));
  });

  test('πλήρες κλείσιμο θέσης', () {
    final p = Position(_holding(price: 5), [
      _trade(TradeSide.buy, 1, 3, 10),
      _trade(TradeSide.sell, 2, 3, 12),
    ]);
    expect(p.isOpen, isFalse);
    expect(p.marketValue, 0);
    expect(p.realizedPnl, closeTo(6, 1e-9));
  });

  test('οι συναλλαγές ταξινομούνται κατά ημερομηνία', () {
    final p = Position(_holding(), [
      _trade(TradeSide.sell, 5, 2, 20),
      _trade(TradeSide.buy, 1, 5, 10),
    ]);
    expect(p.quantity, 3);
    expect(p.realizedPnl, closeTo(20, 1e-9));
  });

  test('πώληση πάνω από τη διαθέσιμη ποσότητα είναι μη έγκυρη', () {
    final result = Position.replay([
      _trade(TradeSide.buy, 1, 2, 10),
      _trade(TradeSide.sell, 2, 3, 10),
    ]);
    expect(result.valid, isFalse);
  });
}
