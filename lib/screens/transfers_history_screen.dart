import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../models/transfer.dart';
import '../utils/money.dart';
import 'transfer_screen.dart';

class TransfersHistoryScreen extends StatefulWidget {
  const TransfersHistoryScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<TransfersHistoryScreen> createState() => _TransfersHistoryScreenState();
}

class _TransfersHistoryScreenState extends State<TransfersHistoryScreen> {
  late final Stream<List<Transfer>> _transfers =
      widget.store.accountsRepo.watchTransfers();

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  String _name(String accountId) =>
      widget.store.accountById(accountId)?.name ?? '(διαγραμμένος)';

  Future<void> _undo(Transfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Αναίρεση μεταφοράς;'),
        content: Text(
          '${formatMoney(t.amountCents, t.currency)} θα επιστρέψουν στο «${_name(t.fromId)}» '
          'και θα αφαιρεθούν από το «${_name(t.toId)}».',
        ),
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
    if (ok != true) return;
    await widget.store.accountsRepo.undoTransfer(
      t,
      existingIds: {for (final a in widget.store.accounts) a.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Μεταφορές')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TransferScreen(store: widget.store),
        )),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Νέα μεταφορά'),
      ),
      body: StreamBuilder<List<Transfer>>(
        stream: _transfers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Σφάλμα: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final transfers = snapshot.data!;
          if (transfers.isEmpty) {
            return const Center(child: Text('Δεν έχεις κάνει μεταφορές ακόμα.'));
          }
          return ListenableBuilder(
            // Για να ενημερώνονται τα ονόματα λογαριασμών.
            listenable: widget.store,
            builder: (context, _) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: transfers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = transfers[i];
                    final amount = t.currency == t.toCurrency
                        ? formatMoney(t.amountCents, t.currency)
                        : '${formatMoney(t.amountCents, t.currency)} → ${formatMoney(t.toAmountCents, t.toCurrency)}';
                    return ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text('${_name(t.fromId)} → ${_name(t.toId)}'),
                      subtitle: Text([
                        _dateFormat.format(t.date),
                        if (t.note.isNotEmpty) t.note,
                      ].join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(amount,
                              style: Theme.of(context).textTheme.titleSmall),
                          IconButton(
                            tooltip: 'Αναίρεση',
                            icon: const Icon(Icons.undo),
                            onPressed: () => _undo(t),
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
    );
  }
}
