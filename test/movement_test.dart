import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/models/movement.dart';

Movement _m(MovementKind kind, int cents) => Movement(
      id: 'm',
      accountId: 'a',
      kind: kind,
      amountCents: cents,
      currency: 'EUR',
      date: DateTime(2026, 10, 5, 12),
      note: 'σούπερ μάρκετ',
    );

void main() {
  test('η πληρωμή αφαιρεί, η είσπραξη προσθέτει', () {
    expect(_m(MovementKind.expense, 4250).signedCents, -4250);
    expect(_m(MovementKind.income, 120000).signedCents, 120000);
  });

  test('αποθήκευση / φόρτωση', () {
    final m = _m(MovementKind.expense, 4250);
    final back = Movement.fromMap('m', m.toMap());
    expect(back.toMap(), m.toMap());
    expect(back.kind, MovementKind.expense);
  });

  test('άγνωστο είδος θεωρείται πληρωμή', () {
    final m = Movement.fromMap('m', {'amountCents': 100, 'kind': '???'});
    expect(m.kind, MovementKind.expense);
    expect(m.currency, 'EUR');
  });
}
