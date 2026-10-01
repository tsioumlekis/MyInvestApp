import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/utils/money.dart';
import 'package:my_invest/utils/privacy.dart';

void main() {
  tearDown(() => hideAmounts.value = false);

  test('η απόκρυψη αφορά μόνο τα σύνολα (maskTotal)', () {
    final total = formatMoney(1801500, 'EUR');
    expect(maskTotal(total), total);

    hideAmounts.value = true;
    expect(maskTotal(total), '•••• €');
  });

  test('τα ποσά λογαριασμών και θέσεων μένουν ορατά', () {
    hideAmounts.value = true;
    expect(formatMoney(164300, 'EUR'), contains('1.643,00'));
    expect(formatAmount(786.28, 'EUR'), contains('786,28'));
    expect(formatSignedAmount(-22.6, 'EUR'), startsWith('−'));
    expect(formatQuantity(48.5), '48,5');
    expect(formatPercent(0.0323), '+3,23%');
  });
}
