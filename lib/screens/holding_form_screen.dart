import 'package:flutter/material.dart';

import '../data/finance_store.dart';
import '../data/instrument_search.dart';
import '../models/account.dart';
import '../models/holding.dart';
import '../utils/money.dart';
import 'instrument_search_screen.dart';
import 'trade_form_screen.dart';

/// Νέα θέση (με την πρώτη αγορά) ή επεξεργασία στοιχείων υπάρχουσας.
class HoldingFormScreen extends StatefulWidget {
  const HoldingFormScreen({super.key, required this.store, this.holding});

  final FinanceStore store;
  final Holding? holding;

  @override
  State<HoldingFormScreen> createState() => _HoldingFormScreenState();
}

class _HoldingFormScreenState extends State<HoldingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _symbol = TextEditingController(text: widget.holding?.symbol);
  late final _name = TextEditingController(text: widget.holding?.name);
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _fees = TextEditingController(text: '0');
  late AssetType _assetType = widget.holding?.assetType ?? AssetType.stock;
  late String _currency = widget.holding?.currency ?? 'EUR';
  late String _exchange = widget.holding?.exchange ?? '';
  late String? _accountId = widget.holding?.accountId ??
      (_accounts.isEmpty ? null : _accounts.first.id);
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.holding != null;

  /// Λογαριασμοί που μπορούν να έχουν θέσεις.
  List<Account> get _accounts => widget.store.accounts
      .where((a) =>
          a.type == AccountType.investment || a.id == widget.holding?.accountId)
      .toList();

  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _fees.dispose();
    super.dispose();
  }

  Future<void> _pickInstrument() async {
    final instrument = await Navigator.of(context).push<Instrument>(
      MaterialPageRoute(
        builder: (_) => InstrumentSearchScreen(initialQuery: _symbol.text),
      ),
    );
    if (instrument == null) return;
    setState(() {
      _symbol.text = instrument.symbol;
      if (instrument.name.isNotEmpty) _name.text = instrument.name;
      _assetType = instrument.type;
      _exchange = instrument.exchange;
      // Σε υπάρχουσα θέση το νόμισμα μένει ίδιο, γιατί οι συναλλαγές είναι σε αυτό.
      if (!_isEdit) _currency = instrument.currency;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = widget.store.investmentsRepo;
    final symbol = _symbol.text.trim().toUpperCase();
    final name = _name.text.trim();

    if (_isEdit) {
      await repo.saveHolding(widget.holding!.copyWith(
        accountId: _accountId,
        symbol: symbol,
        name: name,
        assetType: _assetType,
        exchange: _exchange,
      ));
    } else {
      await repo.addHolding(
        accountId: _accountId!,
        symbol: symbol,
        name: name,
        assetType: _assetType,
        currency: _currency,
        exchange: _exchange,
        date: _date,
        quantity: parseDecimal(_quantity.text)!,
        price: parseDecimal(_price.text)!,
        fees: parseDecimal(_fees.text) ?? 0,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Επεξεργασία θέσης' : 'Νέα θέση')),
      body: accounts.isEmpty
          ? const _NoInvestmentAccount()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _accountId,
                        decoration:
                            const InputDecoration(labelText: 'Λογαριασμός'),
                        items: [
                          for (final a in accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.institution.label})'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _symbol,
                              readOnly: true,
                              onTap: _pickInstrument,
                              decoration: InputDecoration(
                                labelText: 'Σύμβολο',
                                hintText: 'Πάτα για αναζήτηση',
                                helperText:
                                    _exchange.isEmpty ? null : _exchange,
                                suffixIcon: const Icon(Icons.search),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Διάλεξε μετοχή / ETF'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<AssetType>(
                              // Το key ξαναχτίζει το πεδίο όταν αλλάζει από την αναζήτηση.
                              key: ValueKey(_assetType),
                              initialValue: _assetType,
                              decoration: const InputDecoration(labelText: 'Είδος'),
                              items: [
                                for (final t in AssetType.values)
                                  DropdownMenuItem(value: t, child: Text(t.label)),
                              ],
                              onChanged: (v) => setState(() => _assetType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Όνομα (προαιρετικά)',
                          hintText: 'π.χ. Apple Inc.',
                        ),
                      ),
                      if (!_isEdit) ...[
                        const SizedBox(height: 24),
                        Text('Πρώτη αγορά',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: DateField(
                                value: _date,
                                onChanged: (d) => setState(() => _date = d),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_currency),
                                initialValue: _currency,
                                decoration:
                                    const InputDecoration(labelText: 'Νόμισμα'),
                                items: [
                                  for (final c in supportedCurrencies)
                                    DropdownMenuItem(value: c, child: Text(c)),
                                ],
                                onChanged: (v) => setState(() => _currency = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TradeAmountFields(
                          quantity: _quantity,
                          price: _price,
                          fees: _fees,
                          currency: _currency,
                        ),
                      ],
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

class _NoInvestmentAccount extends StatelessWidget {
  const _NoInvestmentAccount();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Δεν έχεις λογαριασμό επενδύσεων ακόμα.\n\n'
          'Πρόσθεσε έναν από την καρτέλα «Λογαριασμοί» '
          '(π.χ. Revolut, κατηγορία «Επενδύσεις») και ξαναδοκίμασε.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
