import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_store.dart';
import '../models/account.dart';
import '../models/holding.dart';
import '../models/transfer.dart';
import '../utils/money.dart';
import '../utils/wealth.dart';
import '../widgets/privacy_toggle.dart';
import '../widgets/sortable_table.dart';
import 'insights_views.dart';

final _date = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

/// Αναλύσεις: όλα τα δεδομένα με γραφικά (προεπιλογή) ή σε πίνακες.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late final Stream<List<Transfer>> _transfers =
      widget.store.accountsRepo.watchTransfers();
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    Widget transfers(Widget Function(List<Transfer>) build) =>
        StreamBuilder<List<Transfer>>(
          stream: _transfers,
          builder: (context, snapshot) => snapshot.hasData
              ? build(snapshot.data!)
              : const Center(child: CircularProgressIndicator()),
        );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Αναλύσεις'),
          actions: [
            const PrivacyToggleButton(),
            IconButton(
              tooltip: _asTable ? 'Γραφική προβολή' : 'Προβολή σε πίνακα',
              icon: Icon(_asTable ? Icons.insights : Icons.table_rows_outlined),
              onPressed: () => setState(() => _asTable = !_asTable),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Λογαριασμοί'),
              Tab(text: 'Θέσεις'),
              Tab(text: 'Συναλλαγές'),
              Tab(text: 'Μεταφορές'),
              Tab(text: 'Ιστορικό'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => TabBarView(
            children: _asTable
                ? [
                    _AccountsTable(store: store),
                    _PositionsTable(store: store),
                    _TradesTable(store: store),
                    transfers((t) => _TransfersTable(store: store, transfers: t)),
                    _HistoryTable(snapshots: store.snapshots),
                  ]
                : [
                    AccountsInsights(store: store),
                    PositionsInsights(store: store),
                    TradesInsights(store: store),
                    transfers((t) => TransfersInsights(store: store, transfers: t)),
                    HistoryInsights(store: store),
                  ],
          ),
        ),
      ),
    );
  }
}

String _eur(double? v) => v == null ? '—' : formatAmount(v, 'EUR');

// ------------------------------------------------------------ Λογαριασμοί

class _AccountRow {
  _AccountRow(this.account, this.holdingsEur, this.totalEur);

  final Account account;
  final double? holdingsEur;
  final double? totalEur;
}

class _AccountsTable extends StatelessWidget {
  const _AccountsTable({required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final fx = store.fx;
    double? toEur(double v, String c) => c == 'EUR' ? v : fx?.toEur(v, c);

    final rows = <_AccountRow>[];
    for (final a in store.accounts) {
      double? holdings = 0;
      for (final p in store.positions
          .where((p) => p.isOpen && p.holding.accountId == a.id)) {
        final v = toEur(p.marketValue, p.holding.currency);
        holdings = (holdings == null || v == null) ? null : holdings + v;
      }
      final cash = toEur(a.balance, a.currency);
      rows.add(_AccountRow(
        a,
        holdings,
        cash == null || holdings == null ? null : cash + holdings,
      ));
    }
    final total = rows.every((r) => r.totalEur != null)
        ? rows.fold(0.0, (s, r) => s + r.totalEur!)
        : null;

    return SortableTable<_AccountRow>(
      rows: rows,
      initialSort: 5,
      initialAscending: false,
      emptyText: 'Δεν υπάρχουν λογαριασμοί.',
      columns: [
        TableCol('Όνομα', text: (r) => r.account.name),
        TableCol('Τράπεζα',
            text: (r) => r.account.type == AccountType.lent
                ? '—'
                : r.account.institution.label),
        TableCol('Κατηγορία', text: (r) => r.account.type.label),
        TableCol('Μετρητά',
            numeric: true,
            sortKey: (r) => r.account.balance,
            text: (r) =>
                formatMoney(r.account.balanceCents, r.account.currency)),
        TableCol('Θέσεις (€)',
            numeric: true,
            sortKey: (r) => r.holdingsEur ?? 0,
            text: (r) => r.holdingsEur == 0 ? '' : _eur(r.holdingsEur)),
        TableCol('Σύνολο (€)',
            numeric: true,
            sortKey: (r) => r.totalEur ?? 0,
            text: (r) => _eur(r.totalEur)),
        TableCol('Ενημέρωση',
            sortKey: (r) => r.account.updatedAt,
            text: (r) => _dateTime.format(r.account.updatedAt)),
      ],
      totals: ['Σύνολο', '', '', '', '', maskTotal(_eur(total)), ''],
    );
  }
}

// ----------------------------------------------------------------- Θέσεις

class _PositionsTable extends StatelessWidget {
  const _PositionsTable({required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final fx = store.fx;
    double? toEur(Position p, double v) =>
        p.holding.currency == 'EUR' ? v : fx?.toEur(v, p.holding.currency);

    final rows = store.positions;
    double? sum(double Function(Position) f) {
      var s = 0.0;
      for (final p in rows) {
        final v = toEur(p, f(p));
        if (v == null) return null;
        s += v;
      }
      return s;
    }

    final value = sum((p) => p.marketValue);
    final cost = sum((p) => p.costBasis);
    final pnl = sum((p) => p.unrealizedPnl);
    final realized = sum((p) => p.realizedPnl);

    Color? pnlOf(BuildContext c, double v) => pnlColor(c, v);

    return SortableTable<Position>(
      rows: rows,
      initialSort: 5,
      initialAscending: false,
      emptyText: 'Δεν υπάρχουν θέσεις.',
      columns: [
        TableCol('Σύμβολο', text: (p) => p.holding.symbol),
        TableCol('Λογαριασμός',
            text: (p) => store.accountById(p.holding.accountId)?.name ?? '—'),
        TableCol('Ποσότητα',
            numeric: true,
            sortKey: (p) => p.quantity,
            text: (p) => formatQuantity(p.quantity)),
        TableCol('Μέση τιμή',
            numeric: true,
            sortKey: (p) => p.avgPrice,
            text: (p) => p.isOpen ? formatPrice(p.avgPrice, p.holding.currency) : '—'),
        TableCol('Τρέχουσα τιμή',
            numeric: true,
            sortKey: (p) => p.holding.currentPrice,
            text: (p) => formatPrice(p.holding.currentPrice, p.holding.currency)),
        TableCol('Αξία',
            numeric: true,
            sortKey: (p) => toEur(p, p.marketValue) ?? 0,
            text: (p) => formatAmount(p.marketValue, p.holding.currency)),
        TableCol('Κόστος',
            numeric: true,
            sortKey: (p) => toEur(p, p.costBasis) ?? 0,
            text: (p) => formatAmount(p.costBasis, p.holding.currency)),
        TableCol('P/L',
            numeric: true,
            sortKey: (p) => toEur(p, p.unrealizedPnl) ?? 0,
            text: (p) => formatSignedAmount(p.unrealizedPnl, p.holding.currency),
            color: (c, p) => pnlOf(c, p.unrealizedPnl)),
        TableCol('P/L %',
            numeric: true,
            sortKey: (p) => p.unrealizedPct ?? 0,
            text: (p) =>
                p.unrealizedPct == null ? '—' : formatPercent(p.unrealizedPct!),
            color: (c, p) => pnlOf(c, p.unrealizedPnl)),
        TableCol('Πραγματοποιημένο',
            numeric: true,
            sortKey: (p) => toEur(p, p.realizedPnl) ?? 0,
            text: (p) => formatSignedAmount(p.realizedPnl, p.holding.currency),
            color: (c, p) => pnlOf(c, p.realizedPnl)),
      ],
      totals: [
        'Σύνολο (€)',
        '',
        '',
        '',
        '',
        maskTotal(_eur(value)),
        maskTotal(_eur(cost)),
        pnl == null ? '—' : maskTotal(formatSignedAmount(pnl, 'EUR')),
        pnl == null || cost == null || cost == 0 ? '' : formatPercent(pnl / cost),
        realized == null ? '—' : maskTotal(formatSignedAmount(realized, 'EUR')),
      ],
    );
  }
}

// ------------------------------------------------------------- Συναλλαγές

class _TradeRow {
  _TradeRow(this.trade, this.holding);

  final Trade trade;
  final Holding holding;

  /// Ποσό που πληρώθηκε (αγορά) ή εισπράχθηκε (πώληση), με τις προμήθειες.
  double get total => trade.side == TradeSide.buy
      ? trade.gross + trade.fees
      : trade.gross - trade.fees;
}

class _TradesTable extends StatelessWidget {
  const _TradesTable({required this.store});

  final FinanceStore store;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final p in store.positions)
        for (final t in p.trades) _TradeRow(t, p.holding),
    ];
    final fees = <String, double>{};
    for (final r in rows) {
      fees[r.holding.currency] = (fees[r.holding.currency] ?? 0) + r.trade.fees;
    }

    return SortableTable<_TradeRow>(
      rows: rows,
      initialSort: 0,
      initialAscending: false,
      emptyText: 'Δεν υπάρχουν συναλλαγές.',
      columns: [
        TableCol('Ημερομηνία',
            sortKey: (r) => r.trade.date, text: (r) => _date.format(r.trade.date)),
        TableCol('Σύμβολο', text: (r) => r.holding.symbol),
        TableCol('Είδος',
            text: (r) => r.trade.side.label,
            color: (c, r) => r.trade.side == TradeSide.buy
                ? Theme.of(c).colorScheme.primary
                : Theme.of(c).colorScheme.tertiary),
        TableCol('Ποσότητα',
            numeric: true,
            sortKey: (r) => r.trade.quantity,
            text: (r) => formatQuantity(r.trade.quantity)),
        TableCol('Τιμή',
            numeric: true,
            sortKey: (r) => r.trade.price,
            text: (r) => formatPrice(r.trade.price, r.holding.currency)),
        TableCol('Προμήθειες',
            numeric: true,
            sortKey: (r) => r.trade.fees,
            text: (r) => formatAmount(r.trade.fees, r.holding.currency)),
        TableCol('Σύνολο',
            numeric: true,
            sortKey: (r) => r.total,
            text: (r) => formatAmount(r.total, r.holding.currency)),
        TableCol('Σημείωση', text: (r) => r.trade.note),
      ],
      totals: [
        'Σύνολο',
        '${rows.length} συναλλαγές',
        '',
        '',
        '',
        fees.entries.map((e) => formatAmount(e.value, e.key)).join(' · '),
        '',
        '',
      ],
    );
  }
}

// -------------------------------------------------------------- Μεταφορές

class _TransfersTable extends StatelessWidget {
  const _TransfersTable({required this.store, required this.transfers});

  final FinanceStore store;
  final List<Transfer> transfers;

  String _name(String id) => store.accountById(id)?.name ?? '(διαγραμμένος)';

  @override
  Widget build(BuildContext context) {
    return SortableTable<Transfer>(
      rows: transfers,
      initialSort: 0,
      initialAscending: false,
      emptyText: 'Δεν υπάρχουν μεταφορές.',
      columns: [
        TableCol('Ημερομηνία',
            sortKey: (t) => t.date, text: (t) => _dateTime.format(t.date)),
        TableCol('Από', text: (t) => _name(t.fromId)),
        TableCol('Προς', text: (t) => _name(t.toId)),
        TableCol('Ποσό',
            numeric: true,
            sortKey: (t) => t.amountCents,
            text: (t) => formatMoney(t.amountCents, t.currency)),
        TableCol('Ποσό που μπήκε',
            numeric: true,
            sortKey: (t) => t.toAmountCents,
            text: (t) => t.currency == t.toCurrency
                ? ''
                : formatMoney(t.toAmountCents, t.toCurrency)),
        TableCol('Σημείωση', text: (t) => t.note),
      ],
    );
  }
}

// --------------------------------------------------------------- Ιστορικό

class _HistoryRow {
  _HistoryRow(this.snapshot, this.change);

  final WealthSnapshot snapshot;

  /// Μεταβολή από το προηγούμενο στιγμιότυπο (null για το πρώτο).
  final double? change;

  double? get changePct {
    final prev = change == null ? null : snapshot.total - change!;
    return prev == null || prev == 0 ? null : change! / prev.abs();
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.snapshots});

  final List<WealthSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var i = 0; i < snapshots.length; i++)
        _HistoryRow(snapshots[i],
            i == 0 ? null : snapshots[i].total - snapshots[i - 1].total),
    ];
    final overall = snapshots.length < 2
        ? null
        : snapshots.last.total - snapshots.first.total;

    return SortableTable<_HistoryRow>(
      rows: rows,
      initialSort: 0,
      initialAscending: false,
      emptyText: 'Το ιστορικό ξεκινά από σήμερα και γεμίζει μία εγγραφή τη μέρα.',
      columns: [
        TableCol('Ημερομηνία',
            sortKey: (r) => r.snapshot.date,
            text: (r) => _date.format(r.snapshot.date)),
        TableCol('Καθαρή περιουσία',
            numeric: true,
            sortKey: (r) => r.snapshot.total,
            text: (r) => maskTotal(formatAmount(r.snapshot.total, 'EUR'))),
        TableCol('Μεταβολή',
            numeric: true,
            sortKey: (r) => r.change ?? 0,
            text: (r) =>
                r.change == null ? '—' : formatSignedAmount(r.change!, 'EUR'),
            color: (c, r) => r.change == null ? null : pnlColor(c, r.change!)),
        TableCol('Μεταβολή %',
            numeric: true,
            sortKey: (r) => r.changePct ?? 0,
            text: (r) =>
                r.changePct == null ? '—' : formatPercent(r.changePct!),
            color: (c, r) => r.change == null ? null : pnlColor(c, r.change!)),
      ],
      totals: overall == null
          ? null
          : [
              'Από την αρχή',
              '',
              formatSignedAmount(overall, 'EUR'),
              snapshots.first.total == 0
                  ? ''
                  : formatPercent(overall / snapshots.first.total.abs()),
            ],
    );
  }
}
