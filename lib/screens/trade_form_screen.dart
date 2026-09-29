import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/investment_repository.dart';
import '../models/holding.dart';
import '../utils/money.dart';

/// Καταχώριση αγοράς ή πώλησης σε υπάρχουσα θέση.
class TradeFormScreen extends StatefulWidget {
  const TradeFormScreen({
    super.key,
    required this.repository,
    required this.position,
    required this.side,
  });

  final InvestmentRepository repository;
  final Position position;
  final TradeSide side;

  @override
  State<TradeFormScreen> createState() => _TradeFormScreenState();
}

class _TradeFormScreenState extends State<TradeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TradeSide _side = widget.side;
  DateTime _date = DateTime.now();
  final _quantity = TextEditingController();
  late final _price = TextEditingController(
      text: decimalToInput(widget.position.holding.currentPrice));
  final _fees = TextEditingController(text: '0');
  final _note = TextEditingController();
  bool _saving = false;

  Holding get _holding => widget.position.holding;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _fees.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _validateQuantity(String? v) {
    final q = parseDecimal(v ?? '');
    if (q == null || q <= 0) return 'Μη έγκυρη ποσότητα';
    if (_side == TradeSide.sell) {
      // Έλεγχος με όλες τις συναλλαγές, για πωλήσεις με παλιότερη ημερομηνία.
      final trades = [
        ...widget.position.trades,
        Trade(
          id: '',
          holdingId: _holding.id,
          side: TradeSide.sell,
          date: _date,
          quantity: q,
          price: 0,
        ),
      ]..sort((a, b) => a.date.compareTo(b.date));
      if (!Position.replay(trades).valid) {
        return 'Μεγαλύτερη από τη διαθέσιμη ποσότητα';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.repository.addTrade(
      holdingId: _holding.id,
      side: _side,
      date: _date,
      quantity: parseDecimal(_quantity.text)!,
      price: parseDecimal(_price.text)!,
      fees: parseDecimal(_fees.text) ?? 0,
      note: _note.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = parseDecimal(_quantity.text) ?? 0;
    final price = parseDecimal(_price.text) ?? 0;
    final fees = parseDecimal(_fees.text) ?? 0;
    final total = _side == TradeSide.buy
        ? quantity * price + fees
        : quantity * price - fees;

    return Scaffold(
      appBar: AppBar(title: Text('${_side.label} ${_holding.symbol}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<TradeSide>(
                  segments: [
                    for (final s in TradeSide.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_side},
                  onSelectionChanged: (v) => setState(() => _side = v.first),
                ),
                if (_side == TradeSide.sell) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Διαθέσιμα: ${formatQuantity(widget.position.quantity)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                DateField(
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: 16),
                TradeAmountFields(
                  quantity: _quantity,
                  price: _price,
                  fees: _fees,
                  currency: _holding.currency,
                  quantityValidator: _validateQuantity,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  decoration:
                      const InputDecoration(labelText: 'Σημείωση (προαιρετικά)'),
                ),
                const SizedBox(height: 16),
                Text(
                  _side == TradeSide.buy
                      ? 'Συνολικό κόστος: ${formatAmount(total, _holding.currency)}'
                      : 'Καθαρό έσοδο: ${formatAmount(total, _holding.currency)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Αποθήκευση'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Πεδία ποσότητας, τιμής και προμηθειών (κοινά σε νέα θέση και συναλλαγή).
class TradeAmountFields extends StatelessWidget {
  const TradeAmountFields({
    super.key,
    required this.quantity,
    required this.price,
    required this.fees,
    required this.currency,
    this.quantityValidator,
  });

  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController fees;
  final String currency;
  final FormFieldValidator<String>? quantityValidator;

  static const _keyboard = TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: quantity,
                decoration: const InputDecoration(labelText: 'Ποσότητα'),
                keyboardType: _keyboard,
                validator: quantityValidator ??
                    (v) {
                      final q = parseDecimal(v ?? '');
                      return q == null || q <= 0 ? 'Μη έγκυρη ποσότητα' : null;
                    },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: price,
                decoration: InputDecoration(
                    labelText: 'Τιμή ανά μονάδα', suffixText: currency),
                keyboardType: _keyboard,
                validator: (v) {
                  final p = parseDecimal(v ?? '');
                  return p == null || p < 0 ? 'Μη έγκυρη τιμή' : null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fees,
          decoration: InputDecoration(
            labelText: 'Προμήθειες / έξοδα',
            suffixText: currency,
          ),
          keyboardType: _keyboard,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final f = parseDecimal(v);
            return f == null || f < 0 ? 'Μη έγκυρο ποσό' : null;
          },
        ),
      ],
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) {
          // Κρατάμε την τρέχουσα ώρα, ώστε συναλλαγές της ίδιας μέρας να
          // μένουν με τη σειρά που καταχωρήθηκαν.
          final now = DateTime.now();
          onChanged(DateTime(picked.year, picked.month, picked.day, now.hour,
              now.minute, now.second));
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Ημερομηνία',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormat('dd/MM/yyyy').format(value)),
      ),
    );
  }
}
