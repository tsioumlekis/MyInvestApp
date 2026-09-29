import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_invest/widgets/sortable_table.dart';

void main() {
  testWidgets('ταξινόμηση με πάτημα στον τίτλο στήλης', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SortableTable<(String, double)>(
          rows: const [('Alpha', 300), ('Revolut', 50), ('Εθνική', 1200)],
          initialSort: 1,
          initialAscending: false,
          columns: [
            TableCol('Όνομα', text: (r) => r.$1),
            TableCol('Ποσό',
                numeric: true, sortKey: (r) => r.$2, text: (r) => '${r.$2}'),
          ],
          totals: const ['Σύνολο', '1550'],
        ),
      ),
    ));

    double y(String text) => tester.getTopLeft(find.text(text)).dy;

    // Αρχικά: φθίνουσα κατά ποσό.
    expect(y('Εθνική') < y('Alpha'), isTrue);
    expect(y('Alpha') < y('Revolut'), isTrue);
    expect(find.text('Σύνολο'), findsOneWidget);

    // Πάτημα στο «Ποσό»: αύξουσα.
    await tester.tap(find.text('Ποσό'));
    await tester.pumpAndSettle();
    expect(y('Revolut') < y('Alpha'), isTrue);
    expect(y('Alpha') < y('Εθνική'), isTrue);

    // Η γραμμή συνόλων μένει πάντα τελευταία.
    expect(y('Εθνική') < y('Σύνολο'), isTrue);
  });

  testWidgets('κενός πίνακας δείχνει μήνυμα', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SortableTable<String>(
          rows: const [],
          emptyText: 'Τίποτα εδώ',
          columns: [TableCol('A', text: (r) => r)],
        ),
      ),
    ));
    expect(find.text('Τίποτα εδώ'), findsOneWidget);
  });
}
