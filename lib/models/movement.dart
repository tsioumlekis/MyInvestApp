enum MovementKind {
  expense('Πληρωμή'),
  income('Είσπραξη');

  const MovementKind(this.label);
  final String label;
}

/// Πληρωμή ή είσπραξη σε έναν λογαριασμό: αλλάζει αυτόματα το υπόλοιπό του.
class Movement {
  Movement({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.amountCents,
    required this.currency,
    required this.date,
    this.note = '',
  });

  final String id;
  final String accountId;
  final MovementKind kind;

  /// Πάντα θετικό· το [kind] δείχνει αν αφαιρείται ή προστίθεται.
  final int amountCents;
  final String currency;
  final DateTime date;
  final String note;

  /// Η μεταβολή στο υπόλοιπο του λογαριασμού (αρνητική για πληρωμή).
  int get signedCents =>
      kind == MovementKind.expense ? -amountCents : amountCents;

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'kind': kind.name,
        'amountCents': amountCents,
        'currency': currency,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Movement.fromMap(String id, Map<String, dynamic> map) => Movement(
        id: id,
        accountId: map['accountId'] as String? ?? '',
        kind: MovementKind.values.asNameMap()[map['kind']] ??
            MovementKind.expense,
        amountCents: map['amountCents'] as int? ?? 0,
        currency: map['currency'] as String? ?? 'EUR',
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        note: map['note'] as String? ?? '',
      );
}
