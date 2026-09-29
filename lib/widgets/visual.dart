import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/money.dart';
import 'charts.dart';

/// Κάρτα ενότητας με τίτλο.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Ο βασικός αριθμός της σελίδας (ένας ανά προβολή).
class HeroFigure extends StatelessWidget {
  const HeroFigure({super.key, required this.label, required this.value, this.delta, this.deltaValue});

  final String label;
  final String value;
  final String? delta;
  final double? deltaValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: text.displaySmall?.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            if (delta != null)
              _DeltaChip(text: delta!, value: deltaValue ?? 0),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.text, required this.value});

  final String text;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = pnlColor(context, value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value > 0
              ? Icons.trending_up
              : value < 0
                  ? Icons.trending_down
                  : Icons.trending_flat,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Κάρτα με έναν αριθμό: ετικέτα, τιμή και προαιρετική μεταβολή.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.delta,
    this.deltaValue,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Χρώμα ταυτότητας (π.χ. της κατηγορίας), δείχνεται ως λωρίδα και εικονίδιο.
  final Color? accent;
  final String? delta;
  final double? deltaValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: accent == null
            ? null
            : Border(left: BorderSide(color: accent!, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent ?? scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            _DeltaChip(text: delta!, value: deltaValue ?? 0),
          ],
        ],
      ),
    );
  }
}

/// Σειρά από [StatTile] σε πλέγμα (2 στήλες στο κινητό, 4 σε φαρδιά οθόνη).
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      }),
    );
  }
}

/// Στρογγυλό σήμα με αρχικό γράμμα ή εικονίδιο, στο χρώμα της οντότητας.
class EntityBadge extends StatelessWidget {
  const EntityBadge({super.key, required this.color, this.label, this.icon, this.size = 40});

  final Color color;
  final String? label;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Κείμενο λευκό ή σκούρο ανάλογα με τη φωτεινότητα του χρώματος.
    final onColor =
        color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, color: onColor, size: size * 0.5)
          : Text(
              (label ?? '?').characters.take(2).toString().toUpperCase(),
              style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.34),
            ),
    );
  }
}

/// Γραμμή λίστας με σήμα, τίτλο, ποσό και μπάρα μεριδίου από κάτω.
class ShareRow extends StatelessWidget {
  const ShareRow({
    super.key,
    required this.badge,
    required this.title,
    required this.amount,
    this.subtitle,
    this.share,
    this.barColor,
    this.trailing,
    this.onTap,
  });

  final Widget badge;
  final String title;
  final String? subtitle;
  final String amount;

  /// Μερίδιο στο σύνολο (0..1). Αν λείπει, δεν δείχνεται μπάρα.
  final double? share;
  final Color? barColor;

  /// Κάτι κάτω από το ποσό (π.χ. P/L).
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (subtitle != null)
                              Text(subtitle!,
                                  style: text.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(amount,
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          ?trailing,
                        ],
                      ),
                    ],
                  ),
                  if (share != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: share!.clamp(0, 1),
                              minHeight: 6,
                              color: barColor ?? seriesColor(context, 0),
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          child: Text(formatShare(share!),
                              textAlign: TextAlign.end,
                              style: text.labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatShare(double ratio) =>
    NumberFormat.decimalPercentPattern(locale: 'el_GR', decimalDigits: 1)
        .format(ratio);

/// Μικρή ετικέτα με κέρδος/ζημιά (με βελάκι, ώστε να μη βασίζεται μόνο στο χρώμα).
class PnlLabel extends StatelessWidget {
  const PnlLabel({super.key, required this.text, required this.value});

  final String text;
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = pnlColor(context, value);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(value >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color, size: 18),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Οριζόντιες μπάρες που ξεκινούν από το μηδέν: δεξιά (μπλε) για θετικά,
/// αριστερά (κόκκινο) για αρνητικά. Κάθε μπάρα έχει ετικέτα με το ποσό.
class DivergingBars extends StatelessWidget {
  const DivergingBars({super.key, required this.items, required this.format});

  final List<(String, double)> items;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final maxAbs = items.fold(0.0, (m, i) => math.max(m, i.$2.abs()));
    if (maxAbs == 0) return const SizedBox.shrink();
    final hasNegative = items.any((i) => i.$2 < 0);
    final hasPositive = items.any((i) => i.$2 > 0);
    final text = Theme.of(context).textTheme;
    final axis = Theme.of(context).colorScheme.outline;

    Widget bar(double value, {required bool alignRight}) => FractionallySizedBox(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: (value.abs() / maxAbs).clamp(0.02, 1.0),
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: divergingColor(context, value),
              borderRadius: BorderRadius.horizontal(
                left: alignRight ? const Radius.circular(4) : Radius.zero,
                right: alignRight ? Radius.zero : const Radius.circular(4),
              ),
            ),
          ),
        );

    return Column(
      children: [
        for (final (label, value) in items)
          Tooltip(
            message: '$label: ${format(value)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(label,
                        style: text.labelMedium, overflow: TextOverflow.ellipsis),
                  ),
                  if (hasNegative)
                    Expanded(
                      child: value < 0
                          ? bar(value, alignRight: true)
                          : const SizedBox(height: 16),
                    ),
                  Container(width: 1, height: 22, color: axis),
                  if (hasPositive)
                    Expanded(
                      child: value > 0
                          ? bar(value, alignRight: false)
                          : const SizedBox(height: 16),
                    ),
                  SizedBox(
                    width: 92,
                    // Ουδέτερο κείμενο: το πρόσημο και η θέση της μπάρας δείχνουν
                    // την κατεύθυνση.
                    child: Text(format(value),
                        textAlign: TextAlign.end,
                        style: text.labelMedium),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Στήλες ανά μήνα (ένα χρώμα), με tooltip στο πάτημα / hover.
class MonthlyBars extends StatelessWidget {
  const MonthlyBars({super.key, required this.months, this.currency = 'EUR'});

  /// (πρώτη μέρα του μήνα, ποσό), σε χρονολογική σειρά.
  final List<(DateTime, double)> months;
  final String currency;

  static final _label = DateFormat('MMM yy', 'el');

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = seriesColor(context, 0);
    final maxY = months.fold(0.0, (m, e) => math.max(m, e.$2));
    final axisStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15 + 1,
          barGroups: [
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: months[i].$2,
                  color: color,
                  width: math.min(28, 240 / months.length),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_safeLabel(months[i].$1), style: axisStyle),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${_safeLabel(months[group.x].$1)}\n${formatAmount(rod.toY, currency)}',
                TextStyle(color: scheme.onInverseSurface, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _safeLabel(DateTime d) {
    try {
      return _label.format(d);
    } catch (_) {
      // Αν δεν έχουν φορτωθεί τα ελληνικά ονόματα μηνών.
      return DateFormat('MM/yy').format(d);
    }
  }
}
