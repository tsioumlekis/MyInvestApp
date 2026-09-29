import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/fx_service.dart';
import '../data/investment_repository.dart';
import '../data/price_service.dart';
import '../firebase_options.dart';

/// Μοναδικό όνομα της περιοδικής εργασίας ανανέωσης τιμών.
const priceRefreshTask = 'price-refresh';

/// Καταχωρεί (μία φορά) την ανανέωση τιμών στο παρασκήνιο του Android.
/// Το Android την τρέχει περίπου κάθε 15 λεπτά (ελάχιστο διάστημα) όταν
/// υπάρχει internet· μπορεί να την καθυστερήσει για εξοικονόμηση μπαταρίας.
Future<void> schedulePriceRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    priceRefreshTask,
    priceRefreshTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

/// Σημείο εισόδου του Android για τις εργασίες παρασκηνίου.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshPricesInBackground();
    } catch (e) {
      debugPrint('Background price refresh failed: $e');
    }
    // Πάντα «επιτυχία»: η επόμενη προσπάθεια γίνεται στο επόμενο διάστημα.
    return true;
  });
}

/// Ανανεώνει τις τιμές των ανοιχτών θέσεων του συνδεδεμένου χρήστη.
Future<void> refreshPricesInBackground() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser ??
      await auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
  if (user == null) return;

  final repo = InvestmentRepository(user.uid);
  final positions =
      await repo.watchPositions().first.timeout(const Duration(seconds: 30));
  final holdings = [
    for (final p in positions)
      if (p.isOpen) p.holding,
  ];
  if (holdings.isEmpty) return;

  final settings =
      await repo.watchSettings().first.timeout(const Duration(seconds: 30));
  final result = await PriceService(fx: FxRates.fromMap(settings['fx']))
      .fetch(holdings);
  if (result.prices.isNotEmpty) await repo.updatePrices(result.prices);
}
