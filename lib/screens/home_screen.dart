import 'package:flutter/material.dart';

import '../data/finance_store.dart';
import 'dashboard_screen.dart';
import 'portfolio_screen.dart';
import 'tables_screen.dart';

/// Κεντρική οθόνη μετά τη σύνδεση, με καρτέλες.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});

  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FinanceStore _store = FinanceStore(widget.uid);
  int _tab = 0;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        if (_store.error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Σφάλμα φόρτωσης: ${_store.error}',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (_store.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              DashboardScreen(store: _store),
              PortfolioScreen(store: _store),
              InsightsScreen(store: _store),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance),
                label: 'Λογαριασμοί',
              ),
              NavigationDestination(
                icon: Icon(Icons.show_chart),
                label: 'Επενδύσεις',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Αναλύσεις',
              ),
            ],
          ),
        );
      },
    );
  }
}
