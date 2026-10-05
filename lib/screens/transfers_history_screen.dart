import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../models/movement.dart';
import '../models/transfer.dart';
import '../utils/money.dart';
import 'payment_screen.dart';
import 'transfer_screen.dart';

/// Ιστορικό κινήσεων: πληρωμές, εισπράξεις και μεταφορές, με αναίρεση.
class TransfersHistoryScreen extends StatefulWidget {
  const TransfersHistoryScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<TransfersHistoryScreen> createState() => _TransfersHistoryScreenState();
}

class _TransfersHistoryScreenState extends State<TransfersHistoryScreen> {
  late final Stream<List<Transfer>> _transfers =
      widget.store.accountsRepo.watchTransfers();
  late final Stream<List<Movement>> _movements =
      widget.store.accountsRepo.watchMovements();

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _name(String accountId) =>
      widget.store.accountById(accountId)?.name ?? '(διαγραμμένος)';

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Αναίρεση'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _undoTransfer(Transfer t) async {
    final ok = await _confirm(
      'Αναίρεση μεταφοράς;',
      '${formatMoney(t.amountCents, t.currency)} θα επιστρέψουν στο «${_name(t.fromId)}» '
          'και θα αφαιρεθούν από το «${_name(t.toId)}».',
    );
    if (!ok) return;
    await widget.store.accountsRepo.undoTransfer(
      t,
      existingIds: {for (final a in widget.store.accounts) a.id},
    );
  }

  Future<void> _undoMovement(Movement m) async {
    final amount = formatMoney(m.amountCents, m.currency);
    final ok = await _confirm(
      'Αναίρεση: ${m.kind.label.toLowerCase()};',
      m.kind == MovementKind.expense
          ? '$amount θα επιστρέψουν στο «${_name(m.accountId)}».'
          : '$amount θα αφαιρεθούν από το «${_name(m.accountId)}».',
    );
    if (!ok) return;
    await widget.store.accountsRepo.undoMovement(
      m,
      accountExists: widget.store.accountById(m.accountId) != null,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ιστορικό κινήσεων'),
        actions: [
          IconButton(
            tooltip: 'Νέα μεταφορά',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => _open(TransferScreen(store: widget.store)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(PaymentScreen(store: widget.store)),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Πληρωμή'),
      ),
      body: StreamBuilder<List<Transfer>>(
        stream: _transfers,
        builder: (context, transfers) => StreamBuilder<List<Movement>>(
          stream: _movements,
          builder: (context, movements) {
            final error = transfers.error ?? movements.error;
            if (error != null) return Center(child: Text('Σφάλμα: $error'));
            if (!transfers.hasData || !movements.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // Όλες οι κινήσεις μαζί, η νεότερη πρώτη.
            final items = <(DateTime, Object)>[
              for (final t in transfers.data!) (t.date, t),
              for (final m in movements.data!) (m.date, m),
            ]..sort((a, b) => b.$1.compareTo(a.$1));
            if (items.isEmpty) {
              return const Center(child: Text('Δεν υπάρχουν κινήσεις ακόμα.'));
            }

            return ListenableBuilder(
              // Για να ενημερώνονται τα ονόματα λογαριασμών.
              listenable: widget.store,
              builder: (context, _) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = items[i].$2;
                      final IconData icon;
                      final String title, amount;
                      final String note;
                      final VoidCallback onUndo;
                      Color? amountColor;

                      if (item is Transfer) {
                        icon = Icons.swap_horiz;
                        title = '${_name(item.fromId)} → ${_name(item.toId)}';
                        amount = item.currency == item.toCurrency
                            ? formatMoney(item.amountCents, item.currency)
                            : '${formatMoney(item.amountCents, item.currency)} → ${formatMoney(item.toAmountCents, item.toCurrency)}';
                        note = item.note;
                        onUndo = () => _undoTransfer(item);
                      } else {
                        final m = item as Movement;
                        final expense = m.kind == MovementKind.expense;
                        icon = expense ? Icons.north_east : Icons.south_west;
                        title = m.note.isEmpty
                            ? '${m.kind.label} · ${_name(m.accountId)}'
                            : m.note;
                        // Το πρόσημο δείχνει την κατεύθυνση (όχι μόνο το χρώμα).
                        amount =
                            '${expense ? '−' : '+'}${formatMoney(m.amountCents, m.currency)}';
                        amountColor = pnlColor(context, expense ? -1 : 1);
                        note = m.note.isEmpty
                            ? ''
                            : '${m.kind.label} · ${_name(m.accountId)}';
                        onUndo = () => _undoMovement(m);
                      }

                      return ListTile(
                        leading: Icon(icon, color: scheme.onSurfaceVariant),
                        title: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          _dateFormat.format(items[i].$1),
                          if (note.isNotEmpty) note,
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(amount,
                                style: text.titleSmall
                                    ?.copyWith(color: amountColor)),
                            IconButton(
                              tooltip: 'Αναίρεση',
                              icon: const Icon(Icons.undo),
                              onPressed: onUndo,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
