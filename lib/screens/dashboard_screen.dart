import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../data/fx_service.dart';
import '../models/account.dart';
import '../models/holding.dart';
import '../utils/money.dart';
import '../widgets/charts.dart';
import '../widgets/privacy_toggle.dart';
import 'account_form_screen.dart';
import 'payment_screen.dart';
import 'transfer_screen.dart';
import 'transfers_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store});

  final FinanceStore store;

  void _openForm(BuildContext context,
      {Account? account, AccountType type = AccountType.cash}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountFormScreen(
        repository: store.accountsRepo,
        account: account,
        initialType: type,
      ),
    ));
  }

  void _openTransfer(BuildContext context, {String? fromId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TransferScreen(store: store, fromId: fromId),
    ));
  }

  void _openPayment(BuildContext context, {String? accountId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentScreen(store: store, accountId: accountId),
    ));
  }

  Future<void> _chooseNew(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Λογαριασμός'),
              subtitle: const Text('Τράπεζα, Revolut, επενδυτικός, trading'),
              onTap: () => Navigator.of(context).pop('account'),
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Δανεικά'),
              subtitle: const Text('Χρήματα που έδωσες σε κάποιον'),
              onTap: () => Navigator.of(context).pop('loan'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Μεταφορά χρημάτων'),
              subtitle: const Text('Από έναν λογαριασμό σε άλλον'),
              onTap: () => Navigator.of(context).pop('transfer'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'account':
        _openForm(context);
      case 'loan':
        _openForm(context, type: AccountType.lent);
      case 'transfer':
        _openTransfer(context);
    }
  }

  /// Επιστροφή (ή μέρος) δανεικού: μειώνει το ποσό που χρωστάει.
  Future<void> _recordRepayment(BuildContext context, Account loan) async {
    final controller = TextEditingController();
    final cents = await showDialog<int>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(builder: (context, setState) {
          void submit() {
            final value = parseMoneyToCents(controller.text);
            if (value == null || value <= 0) {
              setState(() => error = 'Μη έγκυρο ποσό');
            } else if (value > loan.balanceCents) {
              setState(() => error = 'Μεγαλύτερο από αυτό που χρωστάει');
            } else {
              Navigator.of(context).pop(value);
            }
          }

          return AlertDialog(
            title: Text('Επιστροφή από ${loan.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Χρωστάει: ${formatMoney(loan.balanceCents, loan.currency)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Ποσό που επέστρεψε',
                    suffixText: loan.currency,
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  controller.text = centsToInput(loan.balanceCents);
                  submit();
                },
                child: const Text('Τα επέστρεψε όλα'),
              ),
              FilledButton(onPressed: submit, child: const Text('Καταχώριση')),
            ],
          );
        });
      },
    );
    controller.dispose();
    if (cents == null) return;
    final remaining = loan.balanceCents - cents;
    final paidNote =
        'Επιστροφή ${formatMoney(cents, loan.currency)} στις ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    await store.accountsRepo.save(loan.copyWith(
      balanceCents: remaining,
      updatedAt: DateTime.now(),
      note: loan.note.isEmpty ? paidNote : '${loan.note}\n$paidNote',
    ));
  }

  Future<void> _updateBalance(BuildContext context, Account account) async {
    final controller =
        TextEditingController(text: centsToInput(account.balanceCents));
    final cents = await showDialog<int>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            void submit() {
              final value = parseMoneyToCents(controller.text);
              if (value == null) {
                setState(() => error = 'Μη έγκυρο ποσό');
              } else {
                Navigator.of(context).pop(value);
              }
            }

            return AlertDialog(
              title: Text(switch (account.type) {
                AccountType.investment => 'Διαθέσιμα μετρητά: ${account.name}',
                AccountType.trading => 'Equity από το MT5: ${account.name}',
                _ => 'Νέο υπόλοιπο: ${account.name}',
              }),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  suffixText: account.currency,
                  errorText: error,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Άκυρο'),
                ),
                FilledButton(onPressed: submit, child: const Text('Ενημέρωση')),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (cents != null) await store.accountsRepo.updateBalance(account, cents);
  }

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    final hasPositions =
        store.positions.any((p) => p.holding.accountId == account.id);
    if (hasPositions) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ο λογαριασμός έχει επενδυτικές θέσεις. Διάγραψέ τες πρώτα από τις Επενδύσεις.'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Διαγραφή λογαριασμού;'),
        content: Text('Ο λογαριασμός «${account.name}» θα διαγραφεί οριστικά.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );
    if (ok == true) await store.accountsRepo.delete(account.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/branding/mark_small.png',
                  width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Text('MyInvest'),
          ],
        ),
        actions: [
          const PrivacyToggleButton(),
          IconButton(
            tooltip: 'Ιστορικό κινήσεων',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TransfersHistoryScreen(store: store),
            )),
          ),
          IconButton(
            tooltip: 'Αποσύνδεση',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // Κύριο κουμπί η πληρωμή (η πιο συχνή ενέργεια)· το «+» για τα υπόλοιπα.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add-account',
            tooltip: 'Προσθήκη λογαριασμού, δανεικού ή μεταφοράς',
            onPressed: () => _chooseNew(context),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add-payment',
            onPressed: () => _openPayment(context),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Πληρωμή'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final accounts = store.accounts;
          if (accounts.isEmpty) return const _EmptyState();

          final byInstitution = <Institution, List<Account>>{};
          final loans = <Account>[];
          for (final a in accounts) {
            if (a.type == AccountType.lent) {
              loans.add(a);
            } else {
              byInstitution.putIfAbsent(a.institution, () => []).add(a);
            }
          }
          // Ανοιχτά δάνεια πρώτα, εξοφλημένα στο τέλος.
          loans.sort((a, b) => (a.balanceCents == 0 ? 1 : 0)
              .compareTo(b.balanceCents == 0 ? 1 : 0));
          final holdingsByAccount = <String, CurrencyTotals>{
            for (final a in accounts)
              a.id: _positionTotals(
                  store.positions.where((p) => p.holding.accountId == a.id)),
          };

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                // Χώρος κάτω για τα δύο κουμπιά, ώστε να μη σκεπάζουν τη λίστα.
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
                children: [
                  _TotalsCard(
                    accounts: accounts,
                    positions: store.positions,
                    fx: store.fx,
                  ),
                  _ChartsSection(store: store),
                  const SizedBox(height: 16),
                  for (final entry in byInstitution.entries)
                    _InstitutionSection(
                      title: entry.key.label,
                      accounts: entry.value,
                      holdingsByAccount: holdingsByAccount,
                      fx: store.fx,
                      onTap: (a) => _updateBalance(context, a),
                      onEdit: (a) => _openForm(context, account: a),
                      onDelete: (a) => _confirmDelete(context, a),
                      onTransfer: (a) => _openTransfer(context, fromId: a.id),
                      onPay: (a) => _openPayment(context, accountId: a.id),
                    ),
                  if (loans.isNotEmpty)
                    _InstitutionSection(
                      title: 'Δανεικά',
                      accounts: loans,
                      holdingsByAccount: holdingsByAccount,
                      fx: store.fx,
                      onTap: (a) => a.balanceCents > 0
                          ? _recordRepayment(context, a)
                          : _openForm(context, account: a),
                      onEdit: (a) => _openForm(context, account: a),
                      onDelete: (a) => _confirmDelete(context, a),
                      onTransfer: (a) => _openTransfer(context, fromId: a.id),
                      onPay: (a) => _openPayment(context, accountId: a.id),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Άθροισμα ανά νόμισμα (σε λεπτά).
typedef CurrencyTotals = Map<String, int>;

void _addTo(CurrencyTotals totals, String currency, int cents) {
  totals[currency] = (totals[currency] ?? 0) + cents;
}

CurrencyTotals _accountTotals(Iterable<Account> accounts) {
  final totals = <String, int>{};
  for (final a in accounts) {
    _addTo(totals, a.currency, a.balanceCents);
  }
  return totals;
}

CurrencyTotals _positionTotals(Iterable<Position> positions) {
  final totals = <String, int>{};
  for (final p in positions.where((p) => p.isOpen)) {
    _addTo(totals, p.holding.currency, (p.marketValue * 100).round());
  }
  return totals;
}

CurrencyTotals _merge(CurrencyTotals a, CurrencyTotals b) {
  final result = {...a};
  b.forEach((currency, cents) => _addTo(result, currency, cents));
  return result;
}

/// Σύνολο σε ευρώ (με «≈» αν έγινε μετατροπή). Αν λείπει κάποια ισοτιμία,
/// δείχνει τα ποσά ανά νόμισμα.
String _formatTotals(CurrencyTotals totals, FxRates? fx) {
  if (totals.isEmpty) return formatMoney(0, 'EUR');
  if (totals.keys.every((c) => c == 'EUR')) {
    return formatMoney(totals['EUR']!, 'EUR');
  }
  if (fx != null) {
    var sum = 0.0;
    var converted = true;
    totals.forEach((currency, cents) {
      final eur = fx.toEur(cents / 100, currency);
      if (eur == null) {
        converted = false;
      } else {
        sum += eur;
      }
    });
    if (converted) return '≈ ${formatAmount(sum, 'EUR')}';
  }
  return totals.entries.map((e) => formatMoney(e.value, e.key)).join('  ·  ');
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard(
      {required this.accounts, required this.positions, required this.fx});

  final List<Account> accounts;
  final List<Position> positions;
  final FxRates? fx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Τα σύνολα κρύβονται με το «ματάκι»· οι λογαριασμοί από κάτω όχι.
    String fmt(CurrencyTotals t) => maskTotal(_formatTotals(t, fx));

    Iterable<Account> ofType(AccountType t) =>
        accounts.where((a) => a.type == t);

    final holdings = _positionTotals(positions);
    final cash = _accountTotals(ofType(AccountType.cash));
    final investments =
        _merge(_accountTotals(ofType(AccountType.investment)), holdings);
    final trading = _accountTotals(ofType(AccountType.trading));
    final lent = _accountTotals(
        ofType(AccountType.lent).where((a) => a.balanceCents != 0));
    final netWorth = _merge(_accountTotals(accounts), holdings);

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Καθαρή περιουσία',
                style: text.labelLarge
                    ?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(
              fmt(netWorth),
              style: text.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${AccountType.cash.label}: ${fmt(cash)}')),
                if (investments.isNotEmpty)
                  Chip(
                    label: Text(
                        '${AccountType.investment.label}: ${fmt(investments)}'),
                  ),
                if (trading.isNotEmpty)
                  Chip(
                    label:
                        Text('${AccountType.trading.label}: ${fmt(trading)}'),
                  ),
                if (lent.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.handshake_outlined, size: 18),
                    label: Text('${AccountType.lent.label}: ${fmt(lent)}'),
                  ),
              ],
            ),
            if (fx != null && netWorth.keys.any((c) => c != 'EUR')) ...[
              const SizedBox(height: 8),
              Text(
                'Μετατροπή με ισοτιμίες ΕΚΤ ${DateFormat('dd/MM/yyyy').format(fx!.date)}'
                ' (1 € = ${fx!.perEur['USD']?.toStringAsFixed(4).replaceAll('.', ',') ?? '-'} \$)',
                style: text.bodySmall
                    ?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstitutionSection extends StatelessWidget {
  const _InstitutionSection({
    required this.title,
    required this.accounts,
    required this.holdingsByAccount,
    required this.fx,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTransfer,
    required this.onPay,
  });

  final ValueChanged<Account> onTransfer;
  final ValueChanged<Account> onPay;

  final String title;
  final List<Account> accounts;
  final FxRates? fx;

  /// Αξία ανοιχτών θέσεων ανά λογαριασμό.
  final Map<String, CurrencyTotals> holdingsByAccount;
  final ValueChanged<Account> onTap;
  final ValueChanged<Account> onEdit;
  final ValueChanged<Account> onDelete;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _subtitle(Account a) {
    if (a.type == AccountType.lent) {
      final status = a.balanceCents == 0 ? 'Εξοφλήθηκε' : 'Σου χρωστάει';
      final firstNote = a.note.split('\n').first;
      return [status, if (firstNote.isNotEmpty) firstNote].join(' · ');
    }
    final holdings = holdingsByAccount[a.id] ?? {};
    if (a.type == AccountType.investment || holdings.isNotEmpty) {
      return 'Μετρητά ${formatMoney(a.balanceCents, a.currency)}'
          ' · Θέσεις ${_formatTotals(holdings, fx)}';
    }
    return '${a.type.label} · ενημ. ${_dateFormat.format(a.updatedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                Text(
                    _formatTotals(
                        accounts.fold(
                            _accountTotals(accounts),
                            (sum, a) =>
                                _merge(sum, holdingsByAccount[a.id] ?? {})),
                        fx),
                    style: text.titleSmall),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    onTap: () => onTap(a),
                    title: Text(a.name),
                    subtitle: Text(_subtitle(a)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTotals(
                              _merge(
                                {a.currency: a.balanceCents},
                                holdingsByAccount[a.id] ?? {},
                              ),
                              fx),
                          style: text.titleMedium?.copyWith(
                            color: a.balanceCents < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) => switch (v) {
                            'pay' => onPay(a),
                            'transfer' => onTransfer(a),
                            'edit' => onEdit(a),
                            _ => onDelete(a),
                          },
                          itemBuilder: (_) => [
                            if (a.type != AccountType.lent)
                              const PopupMenuItem(
                                  value: 'pay',
                                  child: Text('Πληρωμή από εδώ')),
                            const PopupMenuItem(
                                value: 'transfer',
                                child: Text('Μεταφορά από εδώ')),
                            const PopupMenuItem(
                                value: 'edit', child: Text('Επεξεργασία')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Διαγραφή')),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Κατανομή περιουσίας και εξέλιξή της στον χρόνο.
class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final wealth = store.wealth;
    if (wealth == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    // Σταθερή θέση χρώματος ανά κατηγορία.
    const slots = {
      AccountType.cash: 0,
      AccountType.investment: 1,
      AccountType.trading: 2,
      AccountType.lent: 3,
    };
    final items = [
      for (final t in AccountType.values)
        AllocationItem(t.label, wealth.byType[t] ?? 0, slots[t]!),
    ];
    final history = store.snapshots;

    Widget card(String title, Widget child) => Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );

    return Column(
      children: [
        if (items.where((i) => i.value > 0).length > 1)
          card('Κατανομή περιουσίας', AllocationBar(items: items)),
        card(
          'Εξέλιξη καθαρής περιουσίας',
          history.length < 2
              ? Text(
                  'Κάθε μέρα αποθηκεύεται αυτόματα η καθαρή σου περιουσία. '
                  'Το διάγραμμα θα εμφανιστεί από αύριο και θα γεμίζει με τον καιρό.',
                  style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              : SizedBox(
                  height: 200,
                  child: TimeLineChart(
                    points: [for (final s in history) (s.date, s.total)],
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Δεν υπάρχουν λογαριασμοί ακόμα',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Πρόσθεσε τους λογαριασμούς σου σε Alpha Bank, Εθνική και Revolut.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
