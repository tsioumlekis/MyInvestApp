import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_invest/data/fx_service.dart';
import 'package:my_invest/data/price_service.dart';
import 'package:my_invest/models/holding.dart';

Holding _h(String id, String symbol, String exchange, String currency,
        [AssetType type = AssetType.etf]) =>
    Holding(
      id: id,
      accountId: 'a',
      symbol: symbol,
      name: '',
      assetType: type,
      currency: currency,
      exchange: exchange,
      currentPrice: 1,
      priceUpdatedAt: DateTime(2026),
    );

Map<String, dynamic> _spark(String symbol, double price, String currency) => {
      'symbol': symbol,
      'response': [
        {
          'meta': {'regularMarketPrice': price, 'currency': currency}
        }
      ],
    };

void main() {
  test('σύμβολα Yahoo ανά χρηματιστήριο', () {
    expect(PriceService.yahooCandidates(_h('1', 'VWCE', 'XETR', 'EUR')),
        ['VWCE.DE']);
    expect(PriceService.yahooCandidates(_h('1', 'BRK.B', 'NYSE', 'USD')),
        ['BRK-B']);
    expect(PriceService.yahooCandidates(_h('1', 'ETE', 'ATHEX', 'EUR')),
        ['ETE.AT']);
    // Άγνωστο χρηματιστήριο: πρώτα ΗΠΑ, μετά τα ευρωπαϊκά.
    final unknown = PriceService.yahooCandidates(_h('1', 'SPYL', '', 'EUR'));
    expect(unknown.first, 'SPYL');
    expect(unknown, contains('SPYL.DE'));
  });

  test('άγνωστο χρηματιστήριο: κρατά την τιμή με το σωστό νόμισμα', () async {
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'spark': {
            'result': [
              _spark('SPYL', 9.5, 'USD'), // άλλος τίτλος σε USD
              _spark('SPYL.DE', 16.77, 'EUR'),
            ]
          }
        }),
        200));
    final result = await PriceService(client: client, isWeb: false)
        .fetch([_h('s', 'SPYL', '', 'EUR')]);
    expect(result.prices, {'s': 16.77});
  });

  test('Yahoo + CoinGecko, με έλεγχο νομίσματος', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'query2.finance.yahoo.com') {
        return http.Response(
            jsonEncode({
              'spark': {
                'result': [
                  _spark('VWCE.DE', 144.5, 'EUR'),
                  _spark('CSPX.L', 700, 'GBp'), // λάθος νόμισμα
                ]
              }
            }),
            200);
      }
      if (request.url.path.endsWith('/simple/price')) {
        return http.Response(jsonEncode({'bitcoin': {'eur': 70000}}), 200);
      }
      return http.Response('not found', 404);
    });

    final result = await PriceService(client: client, isWeb: false).fetch([
      _h('v', 'VWCE', 'XETR', 'EUR'),
      _h('c', 'CSPX', 'LSE', 'USD'),
      _h('b', 'BTC', '', 'EUR', AssetType.crypto),
    ]);
    expect(result.prices, {'v': 144.5, 'b': 70000});
    expect(result.failed, ['CSPX']);
  });

  test('θέση σε EUR για τίτλο σε USD: μετατροπή με ισοτιμία', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'spark': {
            'result': [_spark('NVDA', 228, 'USD')]
          }
        }),
        200));
    final fx = FxRates({'USD': 1.14}, DateTime(2026));
    final result = await PriceService(client: client, fx: fx, isWeb: false)
        .fetch([_h('n', 'NVDA', 'NASDAQ', 'EUR', AssetType.stock)]);
    expect(result.prices['n'], closeTo(200, 1e-9));

    // Χωρίς ισοτιμίες δεν δίνει λάθος τιμή.
    final noFx = await PriceService(client: client, isWeb: false)
        .fetch([_h('n', 'NVDA', 'NASDAQ', 'EUR', AssetType.stock)]);
    expect(noFx.prices, isEmpty);
  });

  test('Web χωρίς κλειδί: οι μετοχές παραλείπονται, όχι αποτυχία', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final result = await PriceService(client: client, isWeb: true)
        .fetch([_h('v', 'VWCE', 'XETR', 'EUR')]);
    expect(result.prices, isEmpty);
    expect(result.failed, isEmpty);
    expect(result.skipped, ['VWCE']);
    expect(result.message, isNull);
  });
}
