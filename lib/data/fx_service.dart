import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/money.dart';

/// Ισοτιμίες με βάση το ευρώ: πόσες μονάδες νομίσματος αντιστοιχούν σε 1 €.
class FxRates {
  const FxRates(this.perEur, this.date);

  final Map<String, double> perEur;
  final DateTime date;

  /// Μετατρέπει σε ευρώ. Επιστρέφει null αν δεν υπάρχει ισοτιμία.
  double? toEur(double amount, String currency) {
    if (currency == 'EUR') return amount;
    final rate = perEur[currency];
    return rate == null || rate == 0 ? null : amount / rate;
  }

  Map<String, dynamic> toMap() => {
        'rates': perEur,
        'date': date.toIso8601String(),
      };

  static FxRates? fromMap(Object? map) {
    if (map is! Map) return null;
    final rates = map['rates'];
    final date = DateTime.tryParse('${map['date']}');
    if (rates is! Map || date == null) return null;
    return FxRates(
      {
        for (final e in rates.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      },
      date,
    );
  }
}

/// Ισοτιμίες της ΕΚΤ μέσω Frankfurter (δωρεάν, χωρίς κλειδί).
class FxService {
  FxService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FxRates> fetch() async {
    final symbols = supportedCurrencies.where((c) => c != 'EUR').join(',');
    final response = await _client
        .get(Uri.https('api.frankfurter.dev', '/v1/latest',
            {'base': 'EUR', 'symbols': symbols}))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = FxRates.fromMap({'rates': body['rates'], 'date': body['date']});
    if (rates == null) throw Exception('Μη έγκυρη απάντηση ισοτιμιών');
    return rates;
  }
}
