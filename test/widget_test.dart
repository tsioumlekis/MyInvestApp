import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/utils/money.dart';

void main() {
  group('parseMoneyToCents', () {
    test('ελληνική μορφή', () {
      expect(parseMoneyToCents('1.234,56'), 123456);
      expect(parseMoneyToCents('12,5'), 1250);
    });

    test('αγγλική μορφή', () {
      expect(parseMoneyToCents('1,234.56'), 123456);
      expect(parseMoneyToCents('1234.56'), 123456);
    });

    test('αρνητικά και σύμβολα', () {
      expect(parseMoneyToCents('-50'), -5000);
      expect(parseMoneyToCents(' 100 € '), 10000);
    });

    test('μη έγκυρα', () {
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('abc'), isNull);
    });
  });
}
