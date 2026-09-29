import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const supportedCurrencies = ['EUR', 'USD', 'GBP', 'CHF'];

const _locale = 'el_GR';

String formatMoney(int cents, String currency) => formatAmount(cents / 100, currency);

String formatAmount(double value, String currency) {
  return NumberFormat.simpleCurrency(locale: _locale, name: currency)
      .format(value);
}

/// Τιμή ανά μονάδα: περισσότερα δεκαδικά για μικρές τιμές (π.χ. crypto).
String formatPrice(double price, String currency) {
  final abs = price.abs();
  final digits = abs == 0 || abs >= 1 ? 2 : (abs >= 0.01 ? 4 : 6);
  final symbol =
      NumberFormat.simpleCurrency(locale: _locale, name: currency).currencySymbol;
  return NumberFormat.currency(
          locale: _locale, name: currency, symbol: symbol, decimalDigits: digits)
      .format(price);
}

String formatQuantity(double quantity) =>
    NumberFormat('#,##0.########', _locale).format(quantity);

/// Ποσοστό με πρόσημο, π.χ. "+12,34%". Το [ratio] είναι κλάσμα (0.1234).
String formatPercent(double ratio) {
  final text = NumberFormat.decimalPercentPattern(locale: _locale, decimalDigits: 2)
      .format(ratio.abs());
  return '${ratio < 0 ? '−' : '+'}$text';
}

/// Ποσό με πρόσημο, για κέρδη/ζημιές.
String formatSignedAmount(double value, String currency) {
  final text = formatAmount(value.abs(), currency);
  return '${value < 0 ? '−' : '+'}$text';
}

/// Χρώμα για κέρδος (πράσινο) / ζημιά (κόκκινο).
Color pnlColor(BuildContext context, double value) {
  if (value.abs() < 0.005) return Theme.of(context).colorScheme.onSurfaceVariant;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (value > 0) return dark ? Colors.green.shade300 : Colors.green.shade700;
  return Theme.of(context).colorScheme.error;
}

/// Μετατρέπει κείμενο χρήστη σε αριθμό. Δέχεται και ελληνική μορφή
/// ("1.234,56") και αγγλική ("1,234.56" ή "1234.56").
/// Επιστρέφει null αν το κείμενο δεν είναι έγκυρος αριθμός.
double? parseDecimal(String input) {
  var s = input.trim().replaceAll(' ', '').replaceAll('€', '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    // Το τελευταίο σύμβολο είναι το δεκαδικό, το άλλο είναι διαχωριστικό χιλιάδων.
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    s = s.replaceAll(',', '.');
  }

  final value = double.tryParse(s);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

/// Όπως το [parseDecimal], αλλά επιστρέφει λεπτά.
int? parseMoneyToCents(String input) {
  final value = parseDecimal(input);
  return value == null ? null : (value * 100).round();
}

String centsToInput(int cents) {
  return (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
}

/// Αριθμός για πεδίο φόρμας, χωρίς περιττά μηδενικά ("12,5" όχι "12,50000000").
String decimalToInput(double value) {
  var s = value.toStringAsFixed(8);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}
