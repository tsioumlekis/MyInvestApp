import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/models/transfer.dart';

void main() {
  test('αποθήκευση / φόρτωση μεταφοράς', () {
    final t = Transfer(
      id: 'x',
      fromId: 'a',
      toId: 'b',
      amountCents: 10000,
      currency: 'EUR',
      toAmountCents: 11403,
      toCurrency: 'USD',
      date: DateTime(2026, 9, 26, 12),
      note: 'Revolut',
    );
    final back = Transfer.fromMap('x', t.toMap());
    expect(back.toMap(), t.toMap());
  });

  test('παλιές εγγραφές χωρίς ποσό προορισμού', () {
    final t = Transfer.fromMap('x', {
      'fromId': 'a',
      'toId': 'b',
      'amountCents': 500,
      'currency': 'EUR',
      'date': '2026-09-26T12:00:00.000',
    });
    expect(t.toAmountCents, 500);
    expect(t.toCurrency, 'EUR');
  });
}
