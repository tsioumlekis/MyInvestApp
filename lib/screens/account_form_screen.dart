import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../models/account.dart';
import '../utils/money.dart';

/// Φόρμα δημιουργίας ή επεξεργασίας λογαριασμού.
/// Αν δοθεί [account] γίνεται επεξεργασία, αλλιώς δημιουργία.
class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({
    super.key,
    required this.repository,
    this.account,
    this.initialType = AccountType.cash,
  });

  final AccountRepository repository;
  final Account? account;

  /// Κατηγορία για νέο λογαριασμό.
  final AccountType initialType;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _note;
  late Institution _institution;
  late AccountType _type;
  late String _currency;
  bool _saving = false;

  bool get _isEdit => widget.account != null;
  bool get _isLoan => _type == AccountType.lent;
  bool get _isTrading => _type == AccountType.trading;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
        text: a == null ? '' : centsToInput(a.balanceCents));
    _note = TextEditingController(text: a?.note ?? '');
    _type = a?.type ?? widget.initialType;
    _institution = a?.institution ??
        (_type == AccountType.trading ? Institution.fpTrading : Institution.alphaBank);
    _currency = a?.currency ?? 'EUR';
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final cents = parseMoneyToCents(_balance.text)!;
    final name = _name.text.trim();
    final note = _note.text.trim();
    // Τα δανεικά δεν ανήκουν σε τράπεζα.
    final institution = _isLoan ? Institution.other : _institution;

    if (_isEdit) {
      final old = widget.account!;
      await widget.repository.save(old.copyWith(
        name: name,
        institution: institution,
        type: _type,
        currency: _currency,
        balanceCents: cents,
        note: note,
        updatedAt:
            cents != old.balanceCents ? DateTime.now() : old.updatedAt,
      ));
    } else {
      await widget.repository.add(
        name: name,
        institution: institution,
        type: _type,
        currency: _currency,
        balanceCents: cents,
        note: note,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((_isEdit, _isLoan)) {
          (false, true) => 'Νέο δανεικό',
          (true, true) => 'Επεξεργασία δανεικού',
          (false, false) => 'Νέος λογαριασμός',
          (true, false) => 'Επεξεργασία λογαριασμού',
        }),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Κατηγορία'),
                  items: [
                    for (final t in AccountType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v!;
                    if (_isTrading && !_isEdit) _institution = Institution.fpTrading;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: _isLoan ? 'Σε ποιον τα έδωσες' : 'Όνομα',
                    hintText: _isLoan
                        ? 'π.χ. Γιώργος'
                        : _isTrading
                            ? 'π.χ. FP – Quantum Queen'
                            : 'π.χ. Ταμιευτήριο, Κύριος λογαριασμός',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Συμπλήρωσε όνομα' : null,
                ),
                if (!_isLoan) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Institution>(
                    key: ValueKey(_institution),
                    initialValue: _institution,
                    decoration:
                        const InputDecoration(labelText: 'Τράπεζα / Πλατφόρμα'),
                    items: [
                      for (final i in Institution.values)
                        DropdownMenuItem(value: i, child: Text(i.label)),
                    ],
                    onChanged: (v) => setState(() => _institution = v!),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _balance,
                        decoration: InputDecoration(
                          labelText: switch (_type) {
                            AccountType.investment =>
                              'Διαθέσιμα μετρητά (μη επενδυμένα)',
                            AccountType.lent => 'Ποσό που σου χρωστάει',
                            AccountType.trading => 'Equity (από το MT5)',
                            _ => 'Υπόλοιπο',
                          },
                          hintText: '0,00',
                          helperText: _type == AccountType.investment
                              ? 'Η αξία των θέσεων προστίθεται αυτόματα από τις Επενδύσεις'
                              : null,
                          helperMaxLines: 2,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (v) => parseMoneyToCents(v ?? '') == null
                            ? 'Μη έγκυρο ποσό'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Νόμισμα'),
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
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: 'Σημείωση (προαιρετικά)',
                    hintText: _isLoan ? 'π.χ. πότε τα έδωσες, πότε θα τα επιστρέψει' : null,
                  ),
                  maxLines: 2,
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
