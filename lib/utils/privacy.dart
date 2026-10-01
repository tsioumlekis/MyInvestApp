import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Αν είναι true, τα ποσά εμφανίζονται ως «••••» (για να μη φαίνονται
/// σε όποιον κοιτάζει την οθόνη). Ισχύει ανά συσκευή.
final ValueNotifier<bool> hideAmounts = ValueNotifier(false);

/// Κείμενο που αντικαθιστά ένα κρυμμένο ποσό.
const hiddenAmount = '••••';

const _prefKey = 'hide_amounts';

/// Φορτώνει την αποθηκευμένη επιλογή της συσκευής.
Future<void> loadPrivacyPreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    hideAmounts.value = prefs.getBool(_prefKey) ?? false;
  } catch (e) {
    debugPrint('Could not load privacy preference: $e');
  }
}

/// Αλλάζει την απόκρυψη και θυμάται την επιλογή στη συσκευή.
Future<void> toggleHideAmounts() async {
  hideAmounts.value = !hideAmounts.value;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, hideAmounts.value);
  } catch (e) {
    debugPrint('Could not save privacy preference: $e');
  }
}
