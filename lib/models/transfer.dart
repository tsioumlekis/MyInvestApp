/// Μεταφορά χρημάτων από έναν λογαριασμό σε άλλον.
class Transfer {
  Transfer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amountCents,
    required this.currency,
    required this.toAmountCents,
    required this.toCurrency,
    required this.date,
    this.note = '',
  });

  final String id;
  final String fromId;
  final String toId;

  /// Ποσό που έφυγε, στο νόμισμα του λογαριασμού προέλευσης.
  final int amountCents;
  final String currency;

  /// Ποσό που μπήκε, στο νόμισμα του λογαριασμού προορισμού
  /// (διαφέρει μόνο όταν αλλάζει νόμισμα).
  final int toAmountCents;
  final String toCurrency;
  final DateTime date;
  final String note;

  Map<String, dynamic> toMap() => {
        'fromId': fromId,
        'toId': toId,
        'amountCents': amountCents,
        'currency': currency,
        'toAmountCents': toAmountCents,
        'toCurrency': toCurrency,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Transfer.fromMap(String id, Map<String, dynamic> map) {
    final amount = map['amountCents'] as int? ?? 0;
    final currency = map['currency'] as String? ?? 'EUR';
    return Transfer(
      id: id,
      fromId: map['fromId'] as String? ?? '',
      toId: map['toId'] as String? ?? '',
      amountCents: amount,
      currency: currency,
      toAmountCents: map['toAmountCents'] as int? ?? amount,
      toCurrency: map['toCurrency'] as String? ?? currency,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }
}
