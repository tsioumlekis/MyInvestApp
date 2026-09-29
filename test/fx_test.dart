import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_invest/data/fx_service.dart';

void main() {
  test('μετατροπή σε ευρώ', () {
    final fx = FxRates({'USD': 1.14}, DateTime(2026, 9, 25));
    expect(fx.toEur(114, 'USD'), closeTo(100, 1e-9));
    expect(fx.toEur(50, 'EUR'), 50);
    expect(fx.toEur(10, 'CHF'), isNull);
  });

  test('αποθήκευση / φόρτωση', () {
    final fx = FxRates({'USD': 1.14, 'GBP': 0.86}, DateTime(2026, 9, 25));
    final back = FxRates.fromMap(fx.toMap())!;
    expect(back.perEur, fx.perEur);
    expect(back.date, fx.date);
    expect(FxRates.fromMap(null), isNull);
  });

  test('Frankfurter', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'base': 'EUR',
          'date': '2026-09-25',
          'rates': {'USD': 1.1403, 'GBP': 0.86045, 'CHF': 0.9445},
        }),
        200));
    final fx = await FxService(client: client).fetch();
    expect(fx.perEur['USD'], 1.1403);
    expect(fx.date, DateTime(2026, 9, 25));
  });
}
