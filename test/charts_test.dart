import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/data/fx_service.dart';
import 'package:my_invest/models/account.dart';
import 'package:my_invest/models/holding.dart';
import 'package:my_invest/utils/wealth.dart';
import 'package:my_invest/widgets/charts.dart';

Account _account(AccountType type, int cents, [String currency = 'EUR']) =>
    Account(
      id: '$type',
      name: '$type',
      institution: Institution.revolut,
      type: type,
      currency: currency,
      balanceCents: cents,
      updatedAt: DateTime(2026),
    );

void main() {
  test('περιουσία σε ευρώ ανά κατηγορία', () {
    final nvda = Holding(
      id: 'n',
      accountId: 'inv',
      symbol: 'NVDA',
      name: '',
      assetType: AssetType.stock,
      currency: 'USD',
      currentPrice: 114,
      priceUpdatedAt: DateTime(2026),
    );
    final position = Position(nvda, [
      Trade(
          id: 't',
          holdingId: 'n',
          side: TradeSide.buy,
          date: DateTime(2026),
          quantity: 1,
          price: 100),
    ]);
    final fx = FxRates({'USD': 1.14}, DateTime(2026));
    final w = WealthBreakdown.compute(
      [
        _account(AccountType.cash, 100000),
        _account(AccountType.lent, 5000),
      ],
      [position],
      fx,
    )!;
    expect(w.byType[AccountType.cash], 1000);
    expect(w.byType[AccountType.investment], closeTo(100, 1e-9));
    expect(w.byType[AccountType.lent], 50);
    expect(w.total, closeTo(1150, 1e-9));
    expect(w.converted, isTrue);

    // Χωρίς ισοτιμία δεν μπορεί να υπολογιστεί.
    expect(WealthBreakdown.compute([], [position], null), isNull);
  });

  testWidgets('τα διαγράμματα σχεδιάζονται χωρίς σφάλματα', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            const AllocationBar(items: [
              AllocationItem('Ρευστό', 1000, 0),
              AllocationItem('Επενδύσεις', 782.6, 1),
              AllocationItem('Δανεικά', 50, 3),
            ]),
            const BarList(items: [('SPYL', 722.6), ('NVDA', 61.4)]),
            SizedBox(
              height: 200,
              child: TimeLineChart(points: [
                (DateTime(2026, 9, 24), 1800),
                (DateTime(2026, 9, 25), 1820.5),
                (DateTime(2026, 9, 26), 1832.6),
              ]),
            ),
          ],
        ),
      ),
    ));
    expect(find.text('Επενδύσεις'), findsOneWidget);
    expect(find.text('SPYL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
