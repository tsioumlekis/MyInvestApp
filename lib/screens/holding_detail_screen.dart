import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../data/fx_service.dart';
import '../models/holding.dart';
import '../utils/money.dart';
import 'holding_form_screen.dart';
import 'trade_form_screen.dart';

class HoldingDetailScreen extends StatelessWidget {
  const HoldingDetailScreen(
      {super.key, required this.store, required this.holdingId});

  final FinanceStore store;
  final String holdingId;

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  void _openTrade(BuildContext context, Position position, TradeSide side) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TradeFormScreen(
        repository: store.investmentsRepo,
        position: position,
        side: side,
      ),
    ));
  }

  Future<void> _updatePrice(BuildContext context, Holding holding) async {
    final controller =
        TextEditingController(text: decimalToInput(holding.currentPrice));
    final price = await showDialog<double>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(builder: (context, setState) {
          void submit() {
            final v = parseDecimal(controller.text);
            if (v == null || v < 0) {
              setState(() => error = 'Μη έγκυρη τιμή');
            } else {
              Navigator.of(context).pop(v);
            }
          }

          return AlertDialog(
            title: Text('Τρέχουσα τιμή ${holding.symbol}'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: holding.currency,
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
        });
      },
    );
    controller.dispose();
    if (price != null) await store.investmentsRepo.updatePrice(holding, price);
  }

  Future<void> _deleteTrade(
      BuildContext context, Position position, Trade trade) async {
    final remaining = position.trades.where((t) => t.id != trade.id).toList();
    if (!Position.replay(remaining).valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Δεν γίνεται: μετά τη διαγραφή κάποια πώληση θα ξεπερνούσε τη διαθέσιμη ποσότητα.'),
      ));
      return;
    }
    final ok = await _confirm(
      context,
      title: 'Διαγραφή συναλλαγής;',
      message:
          '${trade.side.label} ${formatQuantity(trade.quantity)} × ${formatPrice(trade.price, position.holding.currency)} '
          'στις ${_dateFormat.format(trade.date)}',
    );
    if (ok) await store.investmentsRepo.deleteTrade(trade.id);
  }

  Future<void> _deleteHolding(BuildContext context, Position position) async {
    final ok = await _confirm(
      context,
      title: 'Διαγραφή θέσης;',
      message:
          'Η θέση ${position.holding.symbol} και όλες οι συναλλαγές της (${position.trades.length}) θα διαγραφούν οριστικά.',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).pop();
    await store.investmentsRepo.deleteHolding(position);
  }

  Future<bool> _confirm(BuildContext context,
      {required String title, required String message}) async {
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
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Διαγραφή'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final position = store.positionById(holdingId);
        if (position == null) {
          return Scaffold(appBar: AppBar());
        }
        final h = position.holding;
        final account = store.accountById(h.accountId);
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(h.symbol),
            actions: [
              IconButton(
                tooltip: 'Επεξεργασία',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HoldingFormScreen(store: store, holding: h),
                )),
              ),
              IconButton(
                tooltip: 'Διαγραφή',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteHolding(context, position),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (h.name.isNotEmpty || account != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        [
                          if (h.name.isNotEmpty) h.name,
                          h.assetType.label,
                          if (account != null) account.name,
                        ].join(' · '),
                        style: text.bodyMedium,
                      ),
                    ),
                  _SummaryCard(
                    position: position,
                    fx: store.fx,
                    onEditPrice: () => _updatePrice(context, h),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openTrade(context, position, TradeSide.buy),
                          icon: const Icon(Icons.add),
                          label: const Text('Αγορά'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: position.isOpen
                              ? () =>
                                  _openTrade(context, position, TradeSide.sell)
                              : null,
                          icon: const Icon(Icons.remove),
                          label: const Text('Πώληση'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Συναλλαγές', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final t in position.trades.reversed)
                          ListTile(
                            leading: Icon(
                              t.side == TradeSide.buy
                                  ? Icons.south_west
                                  : Icons.north_east,
                              color: t.side == TradeSide.buy
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                            title: Text(
                                '${t.side.label} ${formatQuantity(t.quantity)} × ${formatPrice(t.price, h.currency)}'),
                            subtitle: Text([
                              _dateFormat.format(t.date),
                              if (t.fees > 0)
                                'προμήθειες ${formatAmount(t.fees, h.currency)}',
                              if (t.note.isNotEmpty) t.note,
                            ].join(' · ')),
                            trailing: IconButton(
                              tooltip: 'Διαγραφή',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  _deleteTrade(context, position, t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.position, required this.fx, required this.onEditPrice});

  final Position position;
  final FxRates? fx;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    final h = position.holding;
    final c = h.currency;
    final text = Theme.of(context).textTheme;
    final pct = position.unrealizedPct;

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: text.bodyMedium)),
              Text(value,
                  style: text.bodyLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Τρέχουσα αξία', style: text.labelLarge),
            Text(formatAmount(position.marketValue, c),
                style: text.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (c != 'EUR' && fx?.toEur(position.marketValue, c) != null)
              Text('≈ ${formatAmount(fx!.toEur(position.marketValue, c)!, 'EUR')}',
                  style: text.bodyMedium),
            if (position.isOpen)
              Text(
                '${formatSignedAmount(position.unrealizedPnl, c)}'
                '${pct == null ? '' : '  (${formatPercent(pct)})'}',
                style: text.titleMedium?.copyWith(
                    color: pnlColor(context, position.unrealizedPnl)),
              ),
            const Divider(height: 24),
            row('Ποσότητα', formatQuantity(position.quantity)),
            row('Μέση τιμή αγοράς', formatPrice(position.avgPrice, c)),
            Row(
              children: [
                Expanded(child: Text('Τρέχουσα τιμή', style: text.bodyMedium)),
                TextButton.icon(
                  onPressed: onEditPrice,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(formatPrice(h.currentPrice, c)),
                ),
              ],
            ),
            row('Κόστος θέσης', formatAmount(position.costBasis, c)),
            row('Πραγματοποιημένο κέρδος',
                formatSignedAmount(position.realizedPnl, c),
                color: pnlColor(context, position.realizedPnl)),
            row('Σύνολο προμηθειών', formatAmount(position.totalFees, c)),
            const SizedBox(height: 4),
            Text(
              'Τιμή ενημερώθηκε ${DateFormat('dd/MM/yyyy HH:mm').format(h.priceUpdatedAt)}',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
