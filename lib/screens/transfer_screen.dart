import 'package:flutter/material.dart';

import '../data/finance_store.dart';
import '../models/account.dart';
import '../utils/money.dart';

/// Μεταφορά χρημάτων από έναν λογαριασμό σε άλλον.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.store, this.fromId, this.toId});

  final FinanceStore store;
  final String? fromId;
  final String? toId;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _toAmount = TextEditingController();
  final _note = TextEditingController();
  late String? _fromId = widget.fromId;
  late String? _toId = widget.toId;

  /// Αν ο χρήστης άλλαξε με το χέρι το ποσό που μπαίνει (σε άλλο νόμισμα).
  bool _toAmountEdited = false;
  bool _saving = false;

  List<Account> get _accounts => widget.store.accounts;
  Account? get _from => _fromId == null ? null : widget.store.accountById(_fromId!);
  Account? get _to => _toId == null ? null : widget.store.accountById(_toId!);
  bool get _crossCurrency =>
      _from != null && _to != null && _from!.currency != _to!.currency;

  @override
  void dispose() {
    _amount.dispose();
    _toAmount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Προτεινόμενο ποσό προορισμού με την ισοτιμία της ΕΚΤ.
  void _suggestToAmount() {
    if (!_crossCurrency || _toAmountEdited) return;
    final amount = parseDecimal(_amount.text);
    final fx = widget.store.fx;
    final eur = amount == null ? null : fx?.toEur(amount, _from!.currency);
    final rate = _to!.currency == 'EUR' ? 1.0 : fx?.perEur[_to!.currency];
    _toAmount.text = eur == null || rate == null
        ? ''
        : (eur * rate).toStringAsFixed(2).replaceAll('.', ',');
  }

  String _label(Account a) {
    final where = a.type == AccountType.lent ? 'Δανεικά' : a.institution.label;
    return '${a.name} · $where · ${formatMoney(a.balanceCents, a.currency)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = parseMoneyToCents(_amount.text)!;
    await widget.store.accountsRepo.transfer(
      from: _from!,
      to: _to!,
      amountCents: amount,
      toAmountCents: _crossCurrency ? parseMoneyToCents(_toAmount.text)! : amount,
      note: _note.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    return Scaffold(
      appBar: AppBar(title: const Text('Μεταφορά χρημάτων')),
      body: _accounts.length < 2
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Χρειάζεσαι τουλάχιστον δύο λογαριασμούς.',
                    textAlign: TextAlign.center),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _fromId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Από'),
                        items: [
                          for (final a in _accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(_label(a),
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        validator: (v) => v == null ? 'Διάλεξε λογαριασμό' : null,
                        onChanged: (v) => setState(() {
                          _fromId = v;
                          if (_toId == v) _toId = null;
                          _toAmountEdited = false;
                          _suggestToAmount();
                        }),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.arrow_downward),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        // Ξαναχτίζεται όταν αλλάζει η προέλευση.
                        key: ValueKey('to-$_fromId-$_toId'),
                        initialValue: _toId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Προς'),
                        items: [
                          for (final a in _accounts)
                            if (a.id != _fromId)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(_label(a),
                                    overflow: TextOverflow.ellipsis),
                              ),
                        ],
                        validator: (v) => v == null ? 'Διάλεξε λογαριασμό' : null,
                        onChanged: (v) => setState(() {
                          _toId = v;
                          _toAmountEdited = false;
                          _suggestToAmount();
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amount,
                        decoration: InputDecoration(
                          labelText: 'Ποσό',
                          suffixText: from?.currency,
                          helperText: from == null
                              ? null
                              : 'Υπόλοιπο: ${formatMoney(from.balanceCents, from.currency)}',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(_suggestToAmount),
                        validator: (v) {
                          final c = parseMoneyToCents(v ?? '');
                          return c == null || c <= 0 ? 'Μη έγκυρο ποσό' : null;
                        },
                      ),
                      if (_crossCurrency) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _toAmount,
                          decoration: InputDecoration(
                            labelText: 'Ποσό που μπαίνει',
                            suffixText: _to!.currency,
                            helperText:
                                'Υπολογίστηκε με την ισοτιμία ΕΚΤ. Άλλαξέ το αν η τράπεζα έδωσε άλλο ποσό.',
                            helperMaxLines: 2,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (_) => _toAmountEdited = true,
                          validator: (v) {
                            final c = parseMoneyToCents(v ?? '');
                            return c == null || c <= 0
                                ? 'Μη έγκυρο ποσό'
                                : null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _note,
                        decoration: const InputDecoration(
                            labelText: 'Σημείωση (προαιρετικά)'),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Μεταφορά'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
