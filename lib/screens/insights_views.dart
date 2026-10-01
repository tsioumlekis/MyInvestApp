import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../models/account.dart';
import '../models/holding.dart';
import '../models/transfer.dart';
import '../utils/money.dart';
import '../widgets/account_badge.dart';
import '../widgets/charts.dart';
import '../widgets/visual.dart';

final _day = DateFormat('dd/MM');
final _fullDate = DateFormat('dd/MM/yyyy');

String _eur(double v) => formatAmount(v, 'EUR');

/// Σύνολο σε ευρώ: κρύβεται όταν είναι ενεργή η απόκρυψη ποσών.
String _total(double v) => maskTotal(_eur(v));

/// Κοινό περίγραμμα κάθε καρτέλας: κύλιση, μέγιστο πλάτος, περιθώρια.
class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: children,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Μετατροπή σε ευρώ με τις ισοτιμίες του store (null αν λείπει ισοτιμία).
double? _toEur(FinanceStore store, double amount, String currency) =>
    currency == 'EUR' ? amount : store.fx?.toEur(amount, currency);

const _typeIcons = {
  AccountType.cash: Icons.payments_outlined,
  AccountType.investment: Icons.show_chart,
  AccountType.trading: Icons.candlestick_chart_outlined,
  AccountType.lent: Icons.handshake_outlined,
};

// ================================================================ Λογαριασμοί

class AccountsInsights extends StatelessWidget {
  const AccountsInsights({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    if (store.accounts.isEmpty) {
      return const _Empty(Icons.account_balance_outlined, 'Δεν υπάρχουν λογαριασμοί ακόμα.');
    }
    final wealth = store.wealth;
    if (wealth == null) {
      return const _Empty(Icons.currency_exchange, 'Φορτώνονται οι ισοτιμίες…');
    }

    // Σύνολο κάθε λογαριασμού σε ευρώ: μετρητά + αξία θέσεων.
    final totals = <String, double>{};
    for (final a in store.accounts) {
      var v = _toEur(store, a.balance, a.currency) ?? 0;
      for (final p in store.positions
          .where((p) => p.isOpen && p.holding.accountId == a.id)) {
        v += _toEur(store, p.marketValue, p.holding.currency) ?? 0;
      }
      totals[a.id] = v;
    }
    final accounts = [...store.accounts]
      ..sort((a, b) => totals[b.id]!.compareTo(totals[a.id]!));
    final positiveTotal =
        totals.values.where((v) => v > 0).fold(0.0, (s, v) => s + v);

    // Ανά τράπεζα (τα δανεικά ως ξεχωριστή ομάδα).
    final byInstitution = <String, (double, int)>{};
    for (final a in store.accounts) {
      final key = institutionName(a);
      final prev = byInstitution[key]?.$1 ?? 0;
      byInstitution[key] = (prev + totals[a.id]!, institutionSlot(a));
    }
    final institutionItems = [
      for (final e in byInstitution.entries) AllocationItem(e.key, e.value.$1, e.value.$2)
    ]..sort((a, b) => a.slot.compareTo(b.slot));

    // Μεταβολή από το προηγούμενο στιγμιότυπο (πριν από σήμερα).
    final today = DateUtils.dateOnly(DateTime.now());
    final previous = store.snapshots.where((s) => s.date.isBefore(today)).lastOrNull;
    final change = previous == null ? null : wealth.total - previous.total;

    return _Page(children: [
      HeroFigure(
        label: 'Καθαρή περιουσία',
        value: maskTotal('${wealth.converted ? '≈ ' : ''}${_eur(wealth.total)}'),
        delta: change == null
            ? null
            : '${formatSignedAmount(change, 'EUR')} από ${_fullDate.format(previous!.date)}',
        deltaValue: change,
      ),
      // Χωρίς χρώματα: σε αυτή τη σελίδα τα χρώματα σημαίνουν τράπεζες.
      KpiGrid(tiles: [
        for (final t in AccountType.values)
          StatTile(
            label: t.label,
            value: _total(wealth.byType[t] ?? 0),
            icon: _typeIcons[t],
          ),
      ]),
      if (institutionItems.where((i) => i.value > 0).length > 1)
        SectionCard(
          title: 'Ανά τράπεζα',
          child: AllocationBar(items: institutionItems),
        ),
      SectionCard(
        title: 'Λογαριασμοί',
        child: Column(
          children: [
            for (final a in accounts)
              ShareRow(
                badge: accountBadge(context, a),
                title: a.name,
                subtitle: a.type == AccountType.lent
                    ? (a.balanceCents == 0 ? 'Δανεικά · εξοφλήθηκε' : 'Δανεικά')
                    : '${institutionName(a)} · ${a.type.label}',
                amount: _eur(totals[a.id]!),
                share: positiveTotal > 0 && totals[a.id]! > 0
                    ? totals[a.id]! / positiveTotal
                    : null,
                barColor: seriesColor(context, institutionSlot(a)),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ==================================================================== Θέσεις

class PositionsInsights extends StatelessWidget {
  const PositionsInsights({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final positions = store.positions;
    if (positions.isEmpty) {
      return const _Empty(Icons.show_chart, 'Δεν υπάρχουν επενδύσεις ακόμα.');
    }

    double eur(Position p, double v) => _toEur(store, v, p.holding.currency) ?? 0;
    var value = 0.0, cost = 0.0, unrealized = 0.0, realized = 0.0, fees = 0.0;
    for (final p in positions) {
      value += eur(p, p.marketValue);
      cost += eur(p, p.costBasis);
      unrealized += eur(p, p.unrealizedPnl);
      realized += eur(p, p.realizedPnl);
      fees += eur(p, p.totalFees);
    }
    final pct = cost > 0 ? unrealized / cost : null;
    final open = positions.where((p) => p.isOpen).toList()
      ..sort((a, b) => eur(b, b.marketValue).compareTo(eur(a, a.marketValue)));

    final pnlItems = [
      for (final p in positions)
        (p.holding.symbol, eur(p, p.unrealizedPnl + p.realizedPnl)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final converted = positions.any((p) => p.holding.currency != 'EUR');

    return _Page(children: [
      HeroFigure(
        label: 'Αξία χαρτοφυλακίου',
        value: maskTotal('${converted ? '≈ ' : ''}${_eur(value)}'),
        delta: '${maskTotal(formatSignedAmount(unrealized, 'EUR'))}'
            '${pct == null ? '' : ' (${formatPercent(pct)})'} ανοιχτό κέρδος',
        deltaValue: unrealized,
      ),
      KpiGrid(tiles: [
        StatTile(label: 'Κόστος', value: _total(cost), icon: Icons.savings_outlined),
        StatTile(
          label: 'Απόδοση',
          value: pct == null ? '—' : formatPercent(pct),
          icon: Icons.percent,
          delta: maskTotal(formatSignedAmount(unrealized, 'EUR')),
          deltaValue: unrealized,
        ),
        StatTile(
          label: 'Πραγματοποιημένο',
          value: maskTotal(formatSignedAmount(realized, 'EUR')),
          icon: Icons.check_circle_outline,
        ),
        StatTile(label: 'Προμήθειες', value: _eur(fees), icon: Icons.receipt_long_outlined),
      ]),
      SectionCard(
        title: 'Κέρδος / ζημιά ανά θέση',
        child: DivergingBars(
          items: pnlItems,
          format: (v) => formatSignedAmount(v, 'EUR'),
        ),
      ),
      if (open.isNotEmpty)
        SectionCard(
          title: 'Ανοιχτές θέσεις',
          child: Column(
            children: [
              for (final p in open)
                ShareRow(
                  badge: EntityBadge(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    label: p.holding.symbol,
                  ),
                  title: p.holding.name.isEmpty
                      ? p.holding.symbol
                      : '${p.holding.symbol} · ${p.holding.name}',
                  subtitle:
                      '${formatQuantity(p.quantity)} × ${formatPrice(p.holding.currentPrice, p.holding.currency)}',
                  amount: formatAmount(p.marketValue, p.holding.currency),
                  trailing: PnlLabel(
                    text: p.unrealizedPct == null
                        ? formatSignedAmount(p.unrealizedPnl, p.holding.currency)
                        : formatPercent(p.unrealizedPct!),
                    value: p.unrealizedPnl,
                  ),
                  share: value > 0 ? eur(p, p.marketValue) / value : null,
                ),
            ],
          ),
        ),
    ]);
  }
}

// =============================================================== Συναλλαγές

class TradesInsights extends StatelessWidget {
  const TradesInsights({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final trades = [
      for (final p in store.positions)
        for (final t in p.trades) (t, p.holding),
    ]..sort((a, b) => b.$1.date.compareTo(a.$1.date));
    if (trades.isEmpty) {
      return const _Empty(Icons.receipt_long_outlined, 'Δεν υπάρχουν συναλλαγές ακόμα.');
    }

    double eur(Trade t, Holding h, double v) => _toEur(store, v, h.currency) ?? 0;
    var buys = 0.0, sells = 0.0, fees = 0.0;
    final byMonth = <DateTime, double>{};
    for (final (t, h) in trades) {
      fees += eur(t, h, t.fees);
      if (t.side == TradeSide.buy) {
        final v = eur(t, h, t.gross + t.fees);
        buys += v;
        final m = DateTime(t.date.year, t.date.month);
        byMonth[m] = (byMonth[m] ?? 0) + v;
      } else {
        sells += eur(t, h, t.gross - t.fees);
      }
    }
    final months = byMonth.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final lastMonths = months.length > 12 ? months.sublist(months.length - 12) : months;

    // Ομαδοποίηση του χρονολογίου ανά μήνα.
    final monthTitle = DateFormat('LLLL yyyy', 'el');
    final groups = <String, List<(Trade, Holding)>>{};
    for (final e in trades) {
      groups.putIfAbsent(_capitalize(monthTitle.format(e.$1.date)), () => []).add(e);
    }
    final scheme = Theme.of(context).colorScheme;

    return _Page(children: [
      KpiGrid(tiles: [
        StatTile(label: 'Αγορές', value: _total(buys), icon: Icons.south_west),
        StatTile(label: 'Πωλήσεις', value: _total(sells), icon: Icons.north_east),
        StatTile(label: 'Προμήθειες', value: _eur(fees), icon: Icons.receipt_long_outlined),
        StatTile(label: 'Συναλλαγές', value: '${trades.length}', icon: Icons.tag),
      ]),
      if (lastMonths.isNotEmpty)
        SectionCard(title: 'Αγορές ανά μήνα', child: MonthlyBars(months: lastMonths)),
      SectionCard(
        title: 'Χρονολόγιο',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(g.key,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.primary)),
              ),
              for (final (t, h) in g.value)
                ShareRow(
                  badge: EntityBadge(
                    color: t.side == TradeSide.buy
                        ? scheme.primaryContainer
                        : scheme.tertiaryContainer,
                    icon: t.side == TradeSide.buy ? Icons.south_west : Icons.north_east,
                  ),
                  title: '${t.side.label} ${h.symbol}',
                  subtitle:
                      '${formatQuantity(t.quantity)} × ${formatPrice(t.price, h.currency)} · ${_fullDate.format(t.date)}',
                  amount: formatAmount(
                      t.side == TradeSide.buy ? t.gross + t.fees : t.gross - t.fees,
                      h.currency),
                  trailing: t.fees > 0
                      ? Text('προμ. ${formatAmount(t.fees, h.currency)}',
                          style: Theme.of(context).textTheme.labelSmall)
                      : null,
                ),
            ],
          ],
        ),
      ),
    ]);
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ================================================================ Μεταφορές

class TransfersInsights extends StatelessWidget {
  const TransfersInsights({super.key, required this.store, required this.transfers});

  final FinanceStore store;
  final List<Transfer> transfers;

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return const _Empty(Icons.swap_horiz, 'Δεν έχεις κάνει μεταφορές ακόμα.');
    }
    double eur(Transfer t) => _toEur(store, t.amountCents / 100, t.currency) ?? 0;

    final now = DateTime.now();
    final total = transfers.fold(0.0, (s, t) => s + eur(t));
    final thisMonth = transfers
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .fold(0.0, (s, t) => s + eur(t));

    // Πού μπήκαν τα χρήματα (εισερχόμενα ανά λογαριασμό).
    final incoming = <String, double>{};
    for (final t in transfers) {
      incoming[t.toId] = (incoming[t.toId] ?? 0) + eur(t);
    }
    final incomingSorted = incoming.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Page(children: [
      KpiGrid(tiles: [
        StatTile(label: 'Μεταφορές', value: '${transfers.length}', icon: Icons.swap_horiz),
        StatTile(label: 'Συνολικό ποσό', value: _eur(total), icon: Icons.functions),
        StatTile(label: 'Αυτόν τον μήνα', value: _eur(thisMonth), icon: Icons.calendar_month),
      ]),
      SectionCard(
        title: 'Πού πήγαν τα χρήματα',
        child: Column(
          children: [
            for (final e in incomingSorted)
              _accountShareRow(context, e.key, e.value, total),
          ],
        ),
      ),
      SectionCard(
        title: 'Κινήσεις',
        child: Column(
          children: [for (final t in transfers) _TransferFlow(store: store, transfer: t)],
        ),
      ),
    ]);
  }

  Widget _accountShareRow(BuildContext context, String id, double value, double total) {
    final a = store.accountById(id);
    return ShareRow(
      badge: a == null
          ? EntityBadge(color: Theme.of(context).colorScheme.outline, label: '?')
          : accountBadge(context, a),
      title: a?.name ?? '(διαγραμμένος)',
      subtitle: a == null ? null : institutionName(a),
      amount: _eur(value),
      share: total > 0 ? value / total : null,
      barColor: a == null ? null : seriesColor(context, institutionSlot(a)),
    );
  }
}

/// Μία μεταφορά ως «από → προς» με τα σήματα των λογαριασμών.
class _TransferFlow extends StatelessWidget {
  const _TransferFlow({required this.store, required this.transfer});

  final FinanceStore store;
  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    final from = store.accountById(t.fromId);
    final to = store.accountById(t.toId);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget side(Account? a) => Expanded(
          child: Row(
            children: [
              a == null
                  ? EntityBadge(color: scheme.outline, label: '?', size: 32)
                  : accountBadge(context, a, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(a?.name ?? '(διαγραμμένος)',
                    style: text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              side(from),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: scheme.primary),
              ),
              side(to),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    DateFormat('dd/MM/yyyy HH:mm').format(t.date),
                    if (t.note.isNotEmpty) t.note,
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                t.currency == t.toCurrency
                    ? formatMoney(t.amountCents, t.currency)
                    : '${formatMoney(t.amountCents, t.currency)} → ${formatMoney(t.toAmountCents, t.toCurrency)}',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================= Ιστορικό

class HistoryInsights extends StatelessWidget {
  const HistoryInsights({super.key, required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final snaps = store.snapshots;
    if (snaps.isEmpty) {
      return const _Empty(Icons.timeline,
          'Το ιστορικό ξεκινά από σήμερα: κάθε μέρα αποθηκεύεται αυτόματα η καθαρή σου περιουσία.');
    }

    final changes = [
      for (var i = 1; i < snaps.length; i++)
        (snaps[i].date, snaps[i].total - snaps[i - 1].total),
    ];
    final overall = snaps.last.total - snaps.first.total;
    final overallPct =
        snaps.first.total == 0 ? null : overall / snaps.first.total.abs();
    (DateTime, double)? best, worst;
    for (final c in changes) {
      if (best == null || c.$2 > best.$2) best = c;
      if (worst == null || c.$2 < worst.$2) worst = c;
    }
    final recent = changes.length > 14 ? changes.sublist(changes.length - 14) : changes;

    return _Page(children: [
      HeroFigure(
        label: 'Καθαρή περιουσία',
        value: _total(snaps.last.total),
        delta: snaps.length < 2
            ? null
            : '${formatSignedAmount(overall, 'EUR')}'
                '${overallPct == null ? '' : ' (${formatPercent(overallPct)})'}'
                ' από ${_fullDate.format(snaps.first.date)}',
        deltaValue: overall,
      ),
      KpiGrid(tiles: [
        StatTile(
          label: 'Καλύτερη μέρα',
          value: best == null ? '—' : formatSignedAmount(best.$2, 'EUR'),
          icon: Icons.arrow_upward,
          delta: best == null ? null : _fullDate.format(best.$1),
          deltaValue: best?.$2,
        ),
        StatTile(
          label: 'Χειρότερη μέρα',
          value: worst == null ? '—' : formatSignedAmount(worst.$2, 'EUR'),
          icon: Icons.arrow_downward,
          delta: worst == null ? null : _fullDate.format(worst.$1),
          deltaValue: worst?.$2,
        ),
        StatTile(label: 'Ημέρες καταγραφής', value: '${snaps.length}', icon: Icons.event_available),
        StatTile(
          label: 'Μέση μεταβολή / μέρα',
          value: changes.isEmpty
              ? '—'
              : formatSignedAmount(overall / changes.length, 'EUR'),
          icon: Icons.show_chart,
        ),
      ]),
      if (snaps.length >= 2)
        SectionCard(
          title: 'Εξέλιξη',
          child: SizedBox(
            height: 220,
            child: TimeLineChart(points: [for (final s in snaps) (s.date, s.total)]),
          ),
        ),
      if (recent.isNotEmpty)
        SectionCard(
          title: 'Ημερήσιες μεταβολές',
          child: DivergingBars(
            items: [for (final (d, v) in recent.reversed) (_day.format(d), v)],
            format: (v) => formatSignedAmount(v, 'EUR'),
          ),
        ),
    ]);
  }
}
