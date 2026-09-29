import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_invest/data/instrument_search.dart';
import 'package:my_invest/models/holding.dart';

void main() {
  test('δημοφιλή: αναζήτηση με σύμβολο ή όνομα', () {
    expect(InstrumentSearch.searchPopular('vwc').map((i) => i.symbol),
        contains('VWCE'));
    expect(InstrumentSearch.searchPopular('apple').map((i) => i.symbol),
        contains('AAPL'));
    expect(InstrumentSearch.searchPopular('εθνική').map((i) => i.symbol),
        contains('ETE'));
  });

  test('online: φιλτράρει warrants/νομίσματα και ταξινομεί', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'status': 'ok',
            'data': [
              {'symbol': 'NVDA1', 'instrument_name': 'Warrant', 'exchange': 'MTA', 'instrument_type': 'Warrant', 'currency': 'EUR'},
              {'symbol': 'NVDA', 'instrument_name': 'NVIDIA', 'exchange': 'BMV', 'instrument_type': 'Common Stock', 'currency': 'MXN'},
              {'symbol': '4NVDA', 'instrument_name': 'NVIDIA', 'exchange': 'MTA', 'instrument_type': 'Common Stock', 'currency': 'EUR'},
              {'symbol': 'NVDA', 'instrument_name': 'NVIDIA Corporation', 'exchange': 'NASDAQ', 'instrument_type': 'Common Stock', 'currency': 'USD'},
            ],
          }),
          200,
        ));
    final results = await InstrumentSearch(client: client).searchOnline('nvda');
    expect(results.map((i) => i.key), ['NVDA@NASDAQ', '4NVDA@MTA']);
    expect(results.first.type, AssetType.stock);
  });
}
