/// Τράπεζα / πλατφόρμα όπου βρίσκεται ο λογαριασμός.
enum Institution {
  alphaBank('Alpha Bank'),
  nbg('Εθνική Τράπεζα'),
  revolut('Revolut'),
  fpTrading('FP Trading'),
  other('Άλλο');

  const Institution(this.label);
  final String label;
}

/// Κατηγορία λογαριασμού.
enum AccountType {
  cash('Ρευστό'),
  investment('Επενδύσεις'),
  trading('Trading'),

  /// Χρήματα που δάνεισα σε κάποιον (απαίτηση).
  lent('Δανεικά');

  const AccountType(this.label);
  final String label;
}

class Account {
  Account({
    required this.id,
    required this.name,
    required this.institution,
    required this.type,
    required this.currency,
    required this.balanceCents,
    required this.updatedAt,
    this.note = '',
  });

  final String id;
  final String name;
  final Institution institution;
  final AccountType type;
  final String currency;

  /// Υπόλοιπο σε λεπτά (int), για να αποφεύγονται σφάλματα στρογγυλοποίησης.
  /// Στους λογαριασμούς trading είναι το Equity από το MT5.
  final int balanceCents;
  final DateTime updatedAt;
  final String note;

  double get balance => balanceCents / 100;

  Account copyWith({
    String? name,
    Institution? institution,
    AccountType? type,
    String? currency,
    int? balanceCents,
    DateTime? updatedAt,
    String? note,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      balanceCents: balanceCents ?? this.balanceCents,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'institution': institution.name,
        'type': type.name,
        'currency': currency,
        'balanceCents': balanceCents,
        'updatedAt': updatedAt.toIso8601String(),
        'note': note,
      };

  factory Account.fromMap(Map<dynamic, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      institution: Institution.values.asNameMap()[map['institution']] ??
          Institution.other,
      type: AccountType.values.asNameMap()[map['type']] ?? AccountType.cash,
      currency: map['currency'] as String? ?? 'EUR',
      balanceCents: map['balanceCents'] as int? ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }
}
