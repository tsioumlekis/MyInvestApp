import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/holding.dart';
import 'fx_service.dart';

class PriceResult {
  PriceResult(this.prices, this.failed, {this.message, this.skipped = const []});

  /// Νέες τιμές ανά holdingId.
  final Map<String, double> prices;

  /// Σύμβολα για τα οποία δεν βρέθηκε τιμή.
  final List<String> failed;

  /// Σύμβολα που δεν αναζητήθηκαν εδώ (μετοχές/ETF στο Web χωρίς κλειδί:
  /// τις ανανεώνει η εφαρμογή Android).
  final List<String> skipped;

  /// Γενικό μήνυμα (π.χ. λείπει κλειδί API).
  final String? message;
}

/// Φέρνει τρέχουσες τιμές:
/// - Μετοχές / ETF: Yahoo Finance (Android), ή Twelve Data στο Web,
///   γιατί ο browser μπλοκάρει το Yahoo (CORS).
/// - Crypto: CoinGecko (παντού).
class PriceService {
  PriceService({http.Client? client, this.twelveDataKey, this.fx, bool? isWeb})
      : _client = client ?? http.Client(),
        _isWeb = isWeb ?? kIsWeb;

  final http.Client _client;
  final String? twelveDataKey;

  /// Ισοτιμίες για θέσεις καταχωρημένες σε άλλο νόμισμα από αυτό του
  /// χρηματιστηρίου (π.χ. NVDA σε EUR ενώ διαπραγματεύεται σε USD).
  final FxRates? fx;
  final bool _isWeb;

  /// Μετατρέπει τιμή από [from] σε [to] μέσω ευρώ. Null αν λείπει ισοτιμία.
  double? _convert(double price, String from, String to) {
    if (from == to) return price;
    final rates = fx;
    if (rates == null) return null;
    final eur = rates.toEur(price, from);
    if (eur == null) return null;
    if (to == 'EUR') return eur;
    final rate = rates.perEur[to];
    return rate == null ? null : eur * rate;
  }

  static const _timeout = Duration(seconds: 15);

  Future<PriceResult> fetch(List<Holding> holdings) async {
    final crypto =
        holdings.where((h) => h.assetType == AssetType.crypto).toList();
    final securities =
        holdings.where((h) => h.assetType != AssetType.crypto).toList();

    final prices = <String, double>{};
    String? message;
    var skipped = <Holding>[];

    if (crypto.isNotEmpty) {
      prices.addAll(await _safe(() => _fetchCoinGecko(crypto)));
    }
    if (securities.isNotEmpty) {
      if (!_isWeb) {
        prices.addAll(await _safe(() => _fetchYahoo(securities)));
      } else if (twelveDataKey != null && twelveDataKey!.isNotEmpty) {
        final (td, tdMessage) = await _fetchTwelveData(securities);
        prices.addAll(td);
        message = tdMessage;
      } else {
        // Στο Web χωρίς κλειδί οι τιμές έρχονται από την εφαρμογή Android.
        skipped = securities;
      }
    }

    final failed = [
      for (final h in holdings)
        if (!prices.containsKey(h.id) && !skipped.contains(h)) h.symbol,
    ];
    return PriceResult(prices, failed,
        message: message, skipped: [for (final h in skipped) h.symbol]);
  }

  Future<Map<String, double>> _safe(
      Future<Map<String, double>> Function() fetch) async {
    try {
      return await fetch();
    } catch (e) {
      debugPrint('Price fetch failed: $e');
      return const {};
    }
  }

  // ---------------------------------------------------------------- Yahoo

  /// Κατάληξη Yahoo για τα κύρια χρηματιστήρια, όταν δεν ξέρουμε σε ποιο
  /// είναι η θέση (π.χ. θέσεις που καταχωρήθηκαν χωρίς αναζήτηση).
  static const _fallbackSuffixes = [
    '.DE', '.AS', '.PA', '.L', '.MI', '.AT', '.SW', '.MC', '.BR', '.F',
  ];

  /// Πιθανά σύμβολα Yahoo για ένα holding, με σειρά προτίμησης.
  /// Κρατιέται το πρώτο που βρεθεί με το ίδιο νόμισμα με τη θέση.
  @visibleForTesting
  static List<String> yahooCandidates(Holding h) {
    final s = h.symbol;
    return switch (h.exchange) {
      'NASDAQ' || 'NYSE' => [s.replaceAll('.', '-')],
      '' => [s.replaceAll('.', '-'), for (final x in _fallbackSuffixes) '$s$x'],
      'XETR' => ['$s.DE'],
      'FSX' => ['$s.F'],
      'LSE' => ['$s.L'],
      'ATHEX' => ['$s.AT'],
      'MTA' => ['$s.MI'],
      'SIX' => ['$s.SW'],
      'BME' => ['$s.MC'],
      'Euronext' => ['$s.AS', '$s.PA', '$s.BR', '$s.LS'],
      _ => [s],
    };
  }

  Future<Map<String, double>> _fetchYahoo(List<Holding> holdings) async {
    final candidates = {for (final h in holdings) h.id: yahooCandidates(h)};
    final allSymbols = {for (final c in candidates.values) ...c}.toList();

    // Yahoo symbol -> (τιμή, νόμισμα)
    final quotes = <String, (double, String)>{};
    for (var i = 0; i < allSymbols.length; i += 20) {
      final chunk = allSymbols.sublist(
          i, i + 20 > allSymbols.length ? allSymbols.length : i + 20);
      final uri = Uri.https('query2.finance.yahoo.com', '/v7/finance/spark', {
        'symbols': chunk.join(','),
        'range': '1d',
        'interval': '1d',
      });
      final response = await _client
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(_timeout);
      if (response.statusCode != 200) continue;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['spark']?['result'] as List?) ?? const [];
      for (final r in results) {
        final symbol = r['symbol'] as String?;
        final responses = r['response'] as List?;
        if (symbol == null || responses == null || responses.isEmpty) continue;
        final meta = responses.first['meta'] as Map<String, dynamic>?;
        final price = (meta?['regularMarketPrice'] as num?)?.toDouble();
        final currency = meta?['currency'] as String?;
        if (price != null && currency != null) {
          quotes[symbol] = (price, currency);
        }
      }
    }

    final prices = <String, double>{};
    for (final h in holdings) {
      final found = candidates[h.id]!.where(quotes.containsKey).toList();
      // Πρώτα τίτλος στο ίδιο νόμισμα με τη θέση.
      final sameCurrency =
          found.where((s) => quotes[s]!.$2 == h.currency).firstOrNull;
      if (sameCurrency != null) {
        prices[h.id] = quotes[sameCurrency]!.$1;
        continue;
      }
      // Αλλιώς μετατροπή από το νόμισμα του χρηματιστηρίου (π.χ. USD → EUR).
      for (final s in found) {
        final converted = _convert(quotes[s]!.$1, quotes[s]!.$2, h.currency);
        if (converted != null) {
          prices[h.id] = converted;
          break;
        }
      }
    }
    return prices;
  }

  // ----------------------------------------------------------- Twelve Data

  Future<(Map<String, double>, String?)> _fetchTwelveData(
      List<Holding> holdings) async {
    final prices = <String, double>{};
    for (final h in holdings) {
      try {
        final params = {'symbol': h.symbol, 'apikey': twelveDataKey!};
        if (h.exchange.isNotEmpty) params['exchange'] = h.exchange;
        final response = await _client
            .get(Uri.https('api.twelvedata.com', '/price', params))
            .timeout(_timeout);
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final price = double.tryParse('${body['price']}');
        if (price != null) {
          prices[h.id] = price;
        } else if (body['code'] == 429) {
          return (
            prices,
            'Όριο Twelve Data (8 τιμές/λεπτό). Ξαναπάτα ανανέωση σε ένα λεπτό.'
          );
        } else if (body['code'] == 401) {
          return (prices, 'Το κλειδί Twelve Data δεν είναι έγκυρο.');
        }
      } catch (e) {
        debugPrint('Twelve Data ${h.symbol}: $e');
      }
    }
    return (prices, null);
  }

  // ------------------------------------------------------------- CoinGecko

  static const _coinIds = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'SOL': 'solana',
    'XRP': 'ripple',
    'ADA': 'cardano',
    'DOGE': 'dogecoin',
    'BNB': 'binancecoin',
    'DOT': 'polkadot',
    'LTC': 'litecoin',
    'LINK': 'chainlink',
    'AVAX': 'avalanche-2',
    'TRX': 'tron',
    'SHIB': 'shiba-inu',
    'USDT': 'tether',
    'USDC': 'usd-coin',
  };

  Future<String?> _coinId(String symbol) async {
    final known = _coinIds[symbol.toUpperCase()];
    if (known != null) return known;
    final response = await _client
        .get(Uri.https('api.coingecko.com', '/api/v3/search', {'query': symbol}))
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final coins = (jsonDecode(response.body)['coins'] as List?) ?? const [];
    for (final c in coins) {
      if ((c['symbol'] as String?)?.toUpperCase() == symbol.toUpperCase()) {
        return c['id'] as String?;
      }
    }
    return null;
  }

  Future<Map<String, double>> _fetchCoinGecko(List<Holding> holdings) async {
    final ids = <String, String>{}; // holdingId -> coinId
    for (final h in holdings) {
      final id = await _coinId(h.symbol);
      if (id != null) ids[h.id] = id;
    }
    if (ids.isEmpty) return const {};

    final currencies = {for (final h in holdings) h.currency.toLowerCase()};
    final response = await _client
        .get(Uri.https('api.coingecko.com', '/api/v3/simple/price', {
          'ids': ids.values.toSet().join(','),
          'vs_currencies': currencies.join(','),
        }))
        .timeout(_timeout);
    if (response.statusCode != 200) return const {};
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final prices = <String, double>{};
    for (final h in holdings) {
      final coin = body[ids[h.id]] as Map<String, dynamic>?;
      final price = (coin?[h.currency.toLowerCase()] as num?)?.toDouble();
      if (price != null) prices[h.id] = price;
    }
    return prices;
  }
}
