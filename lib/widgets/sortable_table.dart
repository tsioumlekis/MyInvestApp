import 'package:flutter/material.dart';

/// Στήλη πίνακα: τίτλος, κλειδί ταξινόμησης και περιεχόμενο κελιού.
class TableCol<T> {
  const TableCol(
    this.label, {
    required this.text,
    this.sortKey,
    this.numeric = false,
    this.color,
  });

  final String label;
  final String Function(T row) text;

  /// Τιμή για ταξινόμηση (αν λείπει, ταξινομεί με το κείμενο).
  final Comparable<Object?> Function(T row)? sortKey;
  final bool numeric;

  /// Προαιρετικό χρώμα κειμένου (π.χ. πράσινο/κόκκινο για P/L).
  final Color? Function(BuildContext context, T row)? color;
}

/// Πίνακας με ταξινόμηση ανά στήλη και προαιρετική γραμμή συνόλων.
/// Κυλάει οριζόντια όταν δεν χωράει.
class SortableTable<T> extends StatefulWidget {
  const SortableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.totals,
    this.initialSort,
    this.initialAscending = true,
    this.emptyText = 'Δεν υπάρχουν δεδομένα.',
  });

  final List<TableCol<T>> columns;
  final List<T> rows;

  /// Κείμενα για τη γραμμή συνόλων, ένα ανά στήλη (κενό = τίποτα).
  final List<String>? totals;
  final int? initialSort;
  final bool initialAscending;
  final String emptyText;

  @override
  State<SortableTable<T>> createState() => _SortableTableState<T>();
}

class _SortableTableState<T> extends State<SortableTable<T>> {
  late int? _sortColumn = widget.initialSort;
  late bool _ascending = widget.initialAscending;

  List<T> get _sorted {
    final rows = [...widget.rows];
    final i = _sortColumn;
    if (i == null) return rows;
    final col = widget.columns[i];
    Comparable<Object?> key(T r) => col.sortKey?.call(r) ?? col.text(r);
    rows.sort((a, b) {
      final c = key(a).compareTo(key(b));
      return _ascending ? c : -c;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(widget.emptyText, textAlign: TextAlign.center),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final bold = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DataTable(
          sortColumnIndex: _sortColumn,
          sortAscending: _ascending,
          headingTextStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
          columnSpacing: 24,
          headingRowHeight: 44,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: [
            for (var i = 0; i < widget.columns.length; i++)
              DataColumn(
                label: Text(widget.columns[i].label),
                numeric: widget.columns[i].numeric,
                onSort: (index, asc) => setState(() {
                  _sortColumn = index;
                  _ascending = asc;
                }),
              ),
          ],
          rows: [
            for (final row in _sorted)
              DataRow(cells: [
                for (final col in widget.columns)
                  DataCell(Text(
                    col.text(row),
                    style: TextStyle(color: col.color?.call(context, row)),
                  )),
              ]),
            if (widget.totals != null)
              DataRow(
                color: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                cells: [
                  for (final t in widget.totals!) DataCell(Text(t, style: bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
