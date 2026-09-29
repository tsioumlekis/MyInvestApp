import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/money.dart';

/// Κατηγορική παλέτα (έλεγχος αχρωματοψίας περασμένος για 6 διαδοχικές
/// θέσεις, σε φωτεινό και σκούρο θέμα). Το χρώμα ακολουθεί την οντότητα,
/// όχι τη σειρά μεγέθους. Επειδή μερικά χρώματα έχουν χαμηλή αντίθεση στο
/// φωτεινό θέμα, κάθε χρωματιστό στοιχείο έχει και ετικέτα κειμένου.
const _seriesLight = [
  Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A),
  Color(0xFFEDA100), Color(0xFFE87BA4), Color(0xFF008300),
];
const _seriesDark = [
  Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70),
  Color(0xFFC98500), Color(0xFFD55181), Color(0xFF008300),
];

Color seriesColor(BuildContext context, int slot) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final palette = dark ? _seriesDark : _seriesLight;
  return palette[slot % palette.length];
}

/// Αποκλίνουσα παλέτα (μπλε = πάνω από το μηδέν, κόκκινο = κάτω).
Color divergingColor(BuildContext context, double value) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (value >= 0) return dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
  return dark ? const Color(0xFFE66767) : const Color(0xFFE34948);
}

class AllocationItem {
  const AllocationItem(this.label, this.value, this.slot);

  final String label;
  final double value;

  /// Σταθερή θέση στην παλέτα για αυτή την κατηγορία.
  final int slot;
}

/// Μία οριζόντια μπάρα 100% με τα μέρη του συνόλου, και από κάτω
/// υπόμνημα με ποσό και ποσοστό για κάθε μέρος (ώστε η ταυτότητα να μη
/// βασίζεται μόνο στο χρώμα).
class AllocationBar extends StatefulWidget {
  const AllocationBar({super.key, required this.items, this.currency = 'EUR'});

  final List<AllocationItem> items;
  final String currency;

  @override
  State<AllocationBar> createState() => _AllocationBarState();
}

class _AllocationBarState extends State<AllocationBar> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((i) => i.value > 0).toList();
    final total = items.fold(0.0, (a, b) => a + b.value);
    if (total <= 0) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    // Ελάχιστο πλάτος ώστε να φαίνονται και τα πολύ μικρά μέρη.
                    flex: math.max(1, (items[i].value / total * 1000).round()),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hovered = i),
                      onExit: (_) => setState(() => _hovered = null),
                      child: Tooltip(
                        message:
                            '${items[i].label}: ${formatAmount(items[i].value, widget.currency)}'
                            ' (${_pct(items[i].value / total)})',
                        child: Container(
                          // Κενό 2px ανάμεσα στα μέρη.
                          margin: EdgeInsets.only(
                              right: i == items.length - 1 ? 0 : 2),
                          color: seriesColor(context, items[i].slot).withValues(
                              alpha: _hovered == null || _hovered == i ? 1 : 0.45),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          Container(
            color: _hovered == i ? surface : null,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: seriesColor(context, items[i].slot),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(items[i].label, style: text.bodyMedium)),
                Text(formatAmount(items[i].value, widget.currency),
                    style: text.bodyMedium),
                SizedBox(
                  width: 64,
                  child: Text(_pct(items[i].value / total),
                      textAlign: TextAlign.end,
                      style: text.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _pct(double ratio) =>
    NumberFormat.decimalPercentPattern(locale: 'el_GR', decimalDigits: 1)
        .format(ratio);

/// Λίστα οριζόντιων μπαρών (ένα χρώμα), π.χ. μερίδιο κάθε θέσης.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.currency = 'EUR'});

  /// (ετικέτα, τιμή) ήδη ταξινομημένα.
  final List<(String, double)> items;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(0.0, (a, b) => a + b.$2);
    final max = items.fold(0.0, (a, b) => math.max(a, b.$2));
    if (total <= 0) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final color = seriesColor(context, 0);
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      children: [
        for (final (label, value) in items)
          Tooltip(
            message: '$label: ${formatAmount(value, currency)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label,
                            style: text.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(_pct(value / total), style: text.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value / max,
                      minHeight: 8,
                      color: color,
                      backgroundColor: track,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Γραμμή εξέλιξης μιας τιμής στον χρόνο (μία σειρά, χωρίς υπόμνημα:
/// ο τίτλος της κάρτας την ονομάζει).
class TimeLineChart extends StatelessWidget {
  const TimeLineChart({super.key, required this.points, this.currency = 'EUR'});

  final List<(DateTime, double)> points;
  final String currency;

  static final _axisDate = DateFormat('dd/MM');
  static final _tipDate = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = seriesColor(context, 0);

    final first = points.first.$1;
    double x(DateTime d) => d.difference(first).inHours / 24;
    final spots = [for (final (d, v) in points) FlSpot(x(d), v)];

    final values = points.map((p) => p.$2);
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final pad = math.max((maxV - minV) * 0.15, maxV.abs() * 0.02 + 1);
    final span = spots.last.x == 0 ? 1.0 : spots.last.x;

    final axisStyle = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final compact = NumberFormat.compactCurrency(
        locale: 'el_GR', symbol: '€', decimalDigits: 1);

    return LineChart(
      LineChartData(
        minY: minV - pad,
        maxY: maxV + pad,
        minX: 0,
        maxX: span,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2,
            isCurved: false,
            dotData: FlDotData(show: spots.length <= 12),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(compact.format(value), style: axisStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: math.max(1, span / 4),
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _axisDate.format(first.add(Duration(hours: (value * 24).round()))),
                  style: axisStyle,
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (touched) => [
              for (final s in touched)
                LineTooltipItem(
                  '${_tipDate.format(first.add(Duration(hours: (s.x * 24).round())))}\n'
                  '${formatAmount(s.y, currency)}',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                ),
            ],
          ),
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: scheme.outline, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
