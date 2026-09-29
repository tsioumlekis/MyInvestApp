import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../data/fx_service.dart';
import '../models/holding.dart';
import '../utils/money.dart';
import '../widgets/charts.dart';
import 'holding_detail_screen.dart';
import 'holding_form_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key, required this.store});

  final FinanceStore store;

  void _openDetail(BuildContext context, Position p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HoldingDetailScreen(store: store, holdingId: p.holding.id),
    ));
  }

  Future<void> _refreshPrices(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await store.refreshPrices();
      final parts = [
        'Ενημερώθηκαν ${result.prices.length} τιμές.',
        if (result.failed.isNotEmpty)
          'Χωρίς τιμή: ${result.failed.join(', ')}.',
        if (result.message != null) result.message!,
      ];
      messenger.showSnackBar(SnackBar(
        content: Text(parts.join('\n')),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Η ανανέωση τιμών απέτυχε: $e')));
    }
  }

  Future<void> _editTwelveDataKey(BuildContext context) async {
    final controller = TextEditingController(text: store.twelveDataKey ?? '');
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Κλειδί Twelve Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Χρειάζεται για τιμές μετοχών/ETF στην έκδοση Web. '
              'Δωρεάν κλειδί από το twelvedata.com (800 κλήσεις/μέρα).',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'API key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Αποθήκευση'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (key != null) await store.saveTwelveDataKey(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Επενδύσεις'),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => store.isRefreshingPrices
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Ανανέωση τιμών',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _refreshPrices(context),
                  ),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _editTwelveDataKey(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'key', child: Text('Κλειδί Twelve Data')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-holding',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HoldingFormScreen(store: store),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Νέα θέση'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final positions = store.positions;
          if (positions.isEmpty) return const _EmptyState();

          final open = positions.where((p) => p.isOpen).toList()
            ..sort((a, b) => b.marketValue.compareTo(a.marketValue));
          final closed = positions.where((p) => !p.isOpen).toList()
            ..sort((a, b) => a.holding.symbol.compareTo(b.holding.symbol));
          final fx = store.fx;
          final currencies = {for (final p in positions) p.holding.currency};
          final eurSummary = _PortfolioTotals.inEur(positions, fx);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (eurSummary != null)
                    _SummaryCard(
                      totals: eurSummary,
                      converted: currencies.any((c) => c != 'EUR'),
                    )
                  else
                    for (final c in currencies)
                      _SummaryCard(
                        totals: _PortfolioTotals.of(
                            c,
                            positions
                                .where((p) => p.holding.currency == c)),
                      ),
                  if (open.isNotEmpty) _PriceStatus(store: store, open: open),
                  if (open.length > 1) _AllocationCard(open: open, fx: fx),
                  const SizedBox(height: 8),
                  if (open.isNotEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final p in open)
                            _PositionTile(
                              position: p,
                              accountName:
                                  store.accountById(p.holding.accountId)?.name,
                              fx: fx,
                              onTap: () => _openDetail(context, p),
                            ),
                        ],
                      ),
                    ),
                  if (closed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: Text('Κλειστές θέσεις (${closed.length})'),
                        children: [
                          for (final p in closed)
                            _PositionTile(
                              position: p,
                              accountName:
                                  store.accountById(p.holding.accountId)?.name,
                              fx: fx,
                              onTap: () => _openDetail(context, p),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Σύνολα χαρτοφυλακίου σε ένα νόμισμα.
class _PortfolioTotals {
  _PortfolioTotals(this.currency);

  final String currency;
  double value = 0, cost = 0, unrealized = 0, realized = 0;

  static _PortfolioTotals of(String currency, Iterable<Position> positions) {
    final t = _PortfolioTotals(currency);
    for (final p in positions) {
      t.value += p.marketValue;
      t.cost += p.costBasis;
      t.unrealized += p.unrealizedPnl;
      t.realized += p.realizedPnl;
    }
    return t;
  }

  /// Όλα σε ευρώ, με τις τρέχουσες ισοτιμίες. Null αν λείπει ισοτιμία.
  static _PortfolioTotals? inEur(List<Position> positions, FxRates? fx) {
    final t = _PortfolioTotals('EUR');
    for (final p in positions) {
      final c = p.holding.currency;
      if (c != 'EUR' && fx?.perEur[c] == null) return null;
      double eur(double v) => c == 'EUR' ? v : fx!.toEur(v, c)!;
      t.value += eur(p.marketValue);
      t.cost += eur(p.costBasis);
      t.unrealized += eur(p.unrealizedPnl);
      t.realized += eur(p.realizedPnl);
    }
    return t;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals, this.converted = false});

  final _PortfolioTotals totals;

  /// Αν περιέχει ποσά που μετατράπηκαν από άλλο νόμισμα.
  final bool converted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final currency = totals.currency;
    final value = totals.value;
    final cost = totals.cost;
    final unrealized = totals.unrealized;
    final realized = totals.realized;
    final pct = cost > 0 ? unrealized / cost : null;
    final onColor = scheme.onPrimaryContainer;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Αξία χαρτοφυλακίου',
                style: text.labelLarge?.copyWith(color: onColor)),
            const SizedBox(height: 4),
            Text('${converted ? '≈ ' : ''}${formatAmount(value, currency)}',
                style: text.headlineMedium?.copyWith(
                    color: onColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Κόστος: ${formatAmount(cost, currency)}')),
                Chip(
                  label: Text(
                    'Ανοιχτό P/L: ${formatSignedAmount(unrealized, currency)}'
                    '${pct == null ? '' : ' (${formatPercent(pct)})'}',
                    style: TextStyle(color: pnlColor(context, unrealized)),
                  ),
                ),
                Chip(
                  label: Text(
                    'Πραγματοποιημένο: ${formatSignedAmount(realized, currency)}',
                    style: TextStyle(color: pnlColor(context, realized)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.position,
    required this.accountName,
    required this.fx,
    required this.onTap,
  });

  final Position position;
  final String? accountName;
  final FxRates? fx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = position.holding;
    final text = Theme.of(context).textTheme;
    final pct = position.unrealizedPct;

    final subtitle = position.isOpen
        ? '${formatQuantity(position.quantity)} × ${formatPrice(h.currentPrice, h.currency)}'
        : 'Πραγματοποιημένο ${formatSignedAmount(position.realizedPnl, h.currency)}';
    final eurValue = h.currency == 'EUR' || !position.isOpen
        ? null
        : fx?.toEur(position.marketValue, h.currency);

    return ListTile(
      onTap: onTap,
      title: Text(h.name.isEmpty ? h.symbol : '${h.symbol} · ${h.name}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        subtitle,
        if (eurValue != null) '≈ ${formatAmount(eurValue, 'EUR')}',
        if (accountName != null) accountName,
      ].join(' · ')),
      trailing: position.isOpen
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatAmount(position.marketValue, h.currency),
                    style: text.titleMedium),
                Text(
                  pct == null
                      ? formatSignedAmount(position.unrealizedPnl, h.currency)
                      : formatPercent(pct),
                  style: text.bodySmall?.copyWith(
                      color: pnlColor(context, position.unrealizedPnl)),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
    );
  }
}

/// Πότε ενημερώθηκαν οι τιμές και για ποιες θέσεις δεν βρέθηκε τιμή.
class _PriceStatus extends StatelessWidget {
  const _PriceStatus({required this.store, required this.open});

  final FinanceStore store;
  final List<Position> open;

  static final _time = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final result = store.lastPriceResult;

    // Η παλαιότερη τιμή από τις ανοιχτές θέσεις.
    final oldest = open
        .map((p) => p.holding.priceUpdatedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    // Η ώρα της πιο παλιάς τιμής: ενημερώνεται και από το παρασκήνιο του
    // Android, οπότε ισχύει και στο Web.
    final line = store.isRefreshingPrices
        ? 'Ανανέωση τιμών…'
        : 'Τιμές ενημερωμένες: ${_time.format(oldest)}'
            '${kIsWeb ? ' · ανανεώνονται αυτόματα από την εφαρμογή Android' : ' · αυτόματη ανανέωση'}';
    final problems = [
      if (result != null && result.failed.isNotEmpty)
        'Χωρίς τιμή: ${result.failed.join(', ')}',
      if (result?.message != null) result!.message!,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: problems.isEmpty
              ? scheme.surfaceContainerHigh
              : scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              problems.isEmpty ? Icons.schedule : Icons.warning_amber_rounded,
              size: 20,
              color: problems.isEmpty ? scheme.onSurfaceVariant : scheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line, style: text.bodyMedium),
                  for (final p in problems)
                    Text(p,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onErrorContainer)),
                  if (problems.isNotEmpty)
                    Text(
                      'Άνοιξε τη θέση → ✏️ και διάλεξέ την ξανά από την αναζήτηση, '
                      'ή βάλε την τιμή με το χέρι.',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Μερίδιο κάθε ανοιχτής θέσης στο χαρτοφυλάκιο (σε ευρώ).
class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.open, required this.fx});

  final List<Position> open;
  final FxRates? fx;

  static const _maxRows = 7;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double)>[];
    for (final p in open) {
      final c = p.holding.currency;
      final eur = c == 'EUR' ? p.marketValue : fx?.toEur(p.marketValue, c);
      if (eur == null) return const SizedBox.shrink();
      rows.add((p.holding.symbol, eur));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    // Οι μικρότερες θέσεις μαζεύονται στο «Άλλα».
    if (rows.length > _maxRows) {
      final rest = rows.sublist(_maxRows - 1).fold(0.0, (a, b) => a + b.$2);
      rows
        ..removeRange(_maxRows - 1, rows.length)
        ..add(('Άλλα', rest));
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Κατανομή χαρτοφυλακίου',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            BarList(items: rows),
          ],
        ),
      ),
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
            Icon(Icons.show_chart,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Δεν υπάρχουν επενδύσεις ακόμα',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Πρόσθεσε τις θέσεις σου (μετοχές, ETF, crypto) με το «Νέα θέση».',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
