enum AssetType {
  stock('Μετοχή'),
  etf('ETF'),
  crypto('Crypto'),
  bond('Ομόλογο'),
  other('Άλλο');

  const AssetType(this.label);
  final String label;
}

enum TradeSide {
  buy('Αγορά'),
  sell('Πώληση');

  const TradeSide(this.label);
  final String label;
}

/// Ένα επενδυτικό προϊόν (π.χ. AAPL) μέσα σε έναν λογαριασμό επενδύσεων.
/// Η ποσότητα και το κόστος δεν αποθηκεύονται εδώ· υπολογίζονται από τις
/// συναλλαγές ([Trade]) στο [Position].
class Holding {
  Holding({
    required this.id,
    required this.accountId,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.currency,
    required this.currentPrice,
    required this.priceUpdatedAt,
    this.exchange = '',
  });

  final String id;
  final String accountId;
  final String symbol;
  final String name;
  final AssetType assetType;
  final String currency;

  /// Χρηματιστήριο (π.χ. NASDAQ, XETR). Κενό αν δεν είναι γνωστό.
  final String exchange;

  /// Τρέχουσα τιμή ανά μονάδα (ενημερώνεται χειροκίνητα προς το παρόν).
  final double currentPrice;
  final DateTime priceUpdatedAt;

  Holding copyWith({
    String? accountId,
    String? symbol,
    String? name,
    AssetType? assetType,
    String? currency,
    String? exchange,
    double? currentPrice,
    DateTime? priceUpdatedAt,
  }) {
    return Holding(
      id: id,
      accountId: accountId ?? this.accountId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      assetType: assetType ?? this.assetType,
      currency: currency ?? this.currency,
      exchange: exchange ?? this.exchange,
      currentPrice: currentPrice ?? this.currentPrice,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'symbol': symbol,
        'name': name,
        'assetType': assetType.name,
        'currency': currency,
        'exchange': exchange,
        'currentPrice': currentPrice,
        'priceUpdatedAt': priceUpdatedAt.toIso8601String(),
      };

  factory Holding.fromMap(String id, Map<String, dynamic> map) {
    return Holding(
      id: id,
      accountId: map['accountId'] as String? ?? '',
      symbol: map['symbol'] as String? ?? '',
      name: map['name'] as String? ?? '',
      assetType:
          AssetType.values.asNameMap()[map['assetType']] ?? AssetType.other,
      currency: map['currency'] as String? ?? 'EUR',
      exchange: map['exchange'] as String? ?? '',
      currentPrice: (map['currentPrice'] as num?)?.toDouble() ?? 0,
      priceUpdatedAt: DateTime.tryParse(map['priceUpdatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Μία αγορά ή πώληση. Τα ποσά είναι στο νόμισμα του [Holding].
class Trade {
  Trade({
    required this.id,
    required this.holdingId,
    required this.side,
    required this.date,
    required this.quantity,
    required this.price,
    this.fees = 0,
    this.note = '',
  });

  final String id;
  final String holdingId;
  final TradeSide side;
  final DateTime date;
  final double quantity;
  final double price;
  final double fees;
  final String note;

  /// Ποσό συναλλαγής χωρίς προμήθειες.
  double get gross => quantity * price;

  Map<String, dynamic> toMap() => {
        'holdingId': holdingId,
        'side': side.name,
        'date': date.toIso8601String(),
        'quantity': quantity,
        'price': price,
        'fees': fees,
        'note': note,
      };

  factory Trade.fromMap(String id, Map<String, dynamic> map) {
    return Trade(
      id: id,
      holdingId: map['holdingId'] as String? ?? '',
      side: TradeSide.values.asNameMap()[map['side']] ?? TradeSide.buy,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      fees: (map['fees'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
    );
  }
}

/// Μια θέση: το [Holding] μαζί με τα αποτελέσματα των συναλλαγών του,
/// υπολογισμένα με τη μέθοδο του μέσου κόστους.
class Position {
  factory Position(Holding holding, Iterable<Trade> trades) {
    final sorted = trades.toList()..sort((a, b) => a.date.compareTo(b.date));
    final result = replay(sorted);
    return Position._(holding, sorted, result);
  }

  Position._(this.holding, this.trades, PositionResult result)
      : quantity = result.quantity,
        costBasis = result.costBasis,
        realizedPnl = result.realizedPnl,
        totalFees = result.totalFees;

  final Holding holding;

  /// Συναλλαγές σε χρονολογική σειρά.
  final List<Trade> trades;

  final double quantity;

  /// Συνολικό κόστος των μονάδων που κρατάμε ακόμα (με τις προμήθειες αγοράς).
  final double costBasis;

  /// Κέρδος/ζημιά από πωλήσεις, μετά από όλες τις προμήθειες.
  final double realizedPnl;
  final double totalFees;

  static const _epsilon = 1e-9;

  bool get isOpen => quantity > _epsilon;
  double get avgPrice => isOpen ? costBasis / quantity : 0;
  double get marketValue => isOpen ? quantity * holding.currentPrice : 0;
  double get unrealizedPnl => isOpen ? marketValue - costBasis : 0;
  double? get unrealizedPct =>
      costBasis > _epsilon ? unrealizedPnl / costBasis : null;

  /// Επαναλαμβάνει τις συναλλαγές (ήδη ταξινομημένες) και επιστρέφει το
  /// αποτέλεσμα. Αν κάποια πώληση ξεπερνά τη διαθέσιμη ποσότητα,
  /// το [PositionResult.valid] είναι false.
  static PositionResult replay(List<Trade> sortedTrades) {
    var quantity = 0.0;
    var cost = 0.0;
    var realized = 0.0;
    var fees = 0.0;
    var valid = true;

    for (final t in sortedTrades) {
      fees += t.fees;
      switch (t.side) {
        case TradeSide.buy:
          quantity += t.quantity;
          cost += t.gross + t.fees;
        case TradeSide.sell:
          if (t.quantity > quantity + _epsilon) valid = false;
          final avg = quantity > _epsilon ? cost / quantity : 0.0;
          final sold = t.quantity.clamp(0.0, quantity);
          realized += t.gross - t.fees - avg * sold;
          cost -= avg * sold;
          quantity -= sold;
          if (quantity <= _epsilon) {
            quantity = 0;
            cost = 0;
          }
      }
    }
    return PositionResult(quantity, cost, realized, fees, valid);
  }
}

class PositionResult {
  const PositionResult(
      this.quantity, this.costBasis, this.realizedPnl, this.totalFees, this.valid);

  final double quantity;
  final double costBasis;
  final double realizedPnl;
  final double totalFees;
  final bool valid;
}
