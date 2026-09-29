import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/holding.dart';
import '../utils/money.dart';
import 'popular_instruments.dart';

/// Ένα διαπραγματεύσιμο προϊόν, όπως επιστρέφεται από την αναζήτηση.
class Instrument {
  const Instrument(this.symbol, this.name, this.exchange, this.currency,
      this.type);

  final String symbol;
  final String name;
  final String exchange;
  final String currency;
  final AssetType type;

  String get key => '$symbol@$exchange';
}

/// Αναζήτηση μετοχών / ETF: πρώτα στη λίστα δημοφιλών (offline),
/// μετά online στο Twelve Data (δωρεάν endpoint, χωρίς κλειδί).
class InstrumentSearch {
  InstrumentSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Χρηματιστήρια που εμφανίζονται πρώτα στα αποτελέσματα.
  static const _preferredExchanges = [
    'NASDAQ', 'NYSE', 'XETR', 'Euronext', 'LSE', 'ATHEX', 'MTA', 'SIX', 'BME',
  ];

  static List<Instrument> searchPopular(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return popularInstruments;
    return popularInstruments
        .where((i) =>
            i.symbol.toLowerCase().startsWith(q) ||
            i.name.toLowerCase().contains(q))
        .toList();
  }

  Future<List<Instrument>> searchOnline(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('api.twelvedata.com', '/symbol_search',
        {'symbol': q, 'outputsize': '30'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') {
      throw Exception(body['message'] ?? 'Άγνωστο σφάλμα αναζήτησης');
    }

    final results = <Instrument>[];
    for (final raw in (body['data'] as List? ?? const [])) {
      final item = raw as Map<String, dynamic>;
      final type = _mapType(item['instrument_type'] as String? ?? '');
      final currency = item['currency'] as String? ?? '';
      // Προϊόντα που δεν υποστηρίζουμε (warrants κ.λπ.) ή νομίσματα εκτός λίστας.
      if (type == null || !supportedCurrencies.contains(currency)) continue;
      results.add(Instrument(
        item['symbol'] as String? ?? '',
        item['instrument_name'] as String? ?? '',
        item['exchange'] as String? ?? '',
        currency,
        type,
      ));
    }

    final upper = q.toUpperCase();
    int rank(Instrument i) {
      final exact = i.symbol == upper ? 0 : 1;
      final exchange = _preferredExchanges.indexOf(i.exchange);
      return exact * 100 + (exchange < 0 ? 50 : exchange);
    }

    // Σταθερή ταξινόμηση: κρατά τη σειρά του API για ίσες βαθμολογίες.
    final indexed = results.asMap().entries.toList()
      ..sort((a, b) {
        final byRank = rank(a.value).compareTo(rank(b.value));
        return byRank != 0 ? byRank : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  static AssetType? _mapType(String type) {
    if (type == 'ETF') return AssetType.etf;
    if (type.contains('Stock') || type.contains('Depositary') || type == 'REIT') {
      return AssetType.stock;
    }
    if (type == 'Digital Currency') return AssetType.crypto;
    if (type == 'Bond') return AssetType.bond;
    return null;
  }
}
