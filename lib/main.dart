import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'background/price_refresh_task.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('el');
  // Ανανέωση τιμών στο παρασκήνιο (μόνο Android). Αν αποτύχει, η εφαρμογή
  // συνεχίζει κανονικά με ανανέωση όσο είναι ανοιχτή.
  try {
    await schedulePriceRefresh();
  } catch (e) {
    debugPrint('Could not schedule background refresh: $e');
  }
  runApp(const MyInvestApp());
}

class MyInvestApp extends StatelessWidget {
  const MyInvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Το πράσινο του λογοτύπου.
    const seed = Color(0xFF2F8F68);
    return MaterialApp(
      title: 'MyInvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const AuthGate(),
    );
  }
}

/// Δείχνει την οθόνη σύνδεσης ή το dashboard, ανάλογα με το αν
/// υπάρχει συνδεδεμένος χρήστης.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return HomeScreen(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}
