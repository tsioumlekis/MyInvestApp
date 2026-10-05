import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/finance_store.dart';
import '../models/account.dart';
import '../models/movement.dart';
import '../utils/money.dart';
import 'trade_form_screen.dart' show DateField;

const _lastAccountKey = 'last_payment_account';

/// Γρήγορη καταχώριση πληρωμής (ή είσπραξης): ποσό + λογαριασμός, και το
/// υπόλοιπο του λογαριασμού αλλάζει αυτόματα.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.store, this.accountId});

  final FinanceStore store;

  /// Προεπιλεγμένος λογαριασμός (αλλιώς αυτός που χρησιμοποιήθηκε τελευταία).
  final String? accountId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  MovementKind _kind = MovementKind.expense;
  late String? _accountId = widget.accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  /// Λογαριασμοί από τους οποίους πληρώνεις: όλοι εκτός από τα δανεικά,
  /// με τους λογαριασμούς ρευστού πρώτους.
  List<Account> get _accounts {
    final all = widget.store.accounts.where((a) => a.type != AccountType.lent);
    return [
      ...all.where((a) => a.type == AccountType.cash),
      ...all.where((a) => a.type != AccountType.cash),
    ];
  }

  Account? get _account =>
      _accountId == null ? null : widget.store.accountById(_accountId!);

  @override
  void initState() {
    super.initState();
    if (_accountId == null) _loadLastAccount();
  }

  Future<void> _loadLastAccount() async {
    String? last;
    try {
      last = (await SharedPreferences.getInstance()).getString(_lastAccountKey);
    } catch (_) {}
    if (!mounted || _accountId != null) return;
    final accounts = _accounts;
    setState(() {
      _accountId = accounts.any((a) => a.id == last)
          ? last
          : (accounts.isEmpty ? null : accounts.first.id);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final account = _account!;
    final cents = parseMoneyToCents(_amount.text)!;
    await widget.store.accountsRepo.addMovement(
      account: account,
      kind: _kind,
      amountCents: cents,
      date: _date,
      note: _note.text.trim(),
    );
    try {
      await (await SharedPreferences.getInstance())
          .setString(_lastAccountKey, account.id);
    } catch (_) {}
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(
        '${_kind.label} ${formatMoney(cents, account.currency)} · ${account.name}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    final account = _account;
    final cents = parseMoneyToCents(_amount.text);
    final after = account == null || cents == null
        ? null
        : account.balanceCents +
            (_kind == MovementKind.expense ? -cents : cents);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(_kind.label)),
      body: accounts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Πρόσθεσε πρώτα έναν λογαριασμό.',
                    textAlign: TextAlign.center),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  onChanged: () => setState(() {}),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SegmentedButton<MovementKind>(
                        segments: const [
                          ButtonSegment(
                            value: MovementKind.expense,
                            icon: Icon(Icons.north_east),
                            label: Text('Πληρωμή'),
                          ),
                          ButtonSegment(
                            value: MovementKind.income,
                            icon: Icon(Icons.south_west),
                            label: Text('Είσπραξη'),
                          ),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (v) =>
                            setState(() => _kind = v.first),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _amount,
                        autofocus: true,
                        style: text.headlineSmall,
                        decoration: InputDecoration(
                          labelText: 'Ποσό',
                          hintText: '0,00',
                          suffixText: account?.currency ?? 'EUR',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final c = parseMoneyToCents(v ?? '');
                          return c == null || c <= 0 ? 'Μη έγκυρο ποσό' : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        // Ξαναχτίζεται όταν φορτώσει ο τελευταίος λογαριασμός.
                        key: ValueKey(_accountId),
                        initialValue: _accountId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _kind == MovementKind.expense
                              ? 'Από ποιον λογαριασμό'
                              : 'Σε ποιον λογαριασμό',
                        ),
                        items: [
                          for (final a in accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} · ${a.institution.label} · ${formatMoney(a.balanceCents, a.currency)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        validator: (v) =>
                            v == null ? 'Διάλεξε λογαριασμό' : null,
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                      if (after != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Νέο υπόλοιπο: ${formatMoney(after, account!.currency)}',
                          style: text.bodyMedium?.copyWith(
                            color: after < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _note,
                        decoration: InputDecoration(
                          labelText: 'Περιγραφή (προαιρετικά)',
                          hintText: _kind == MovementKind.expense
                              ? 'π.χ. σούπερ μάρκετ, βενζίνη'
                              : 'π.χ. μισθός',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      DateField(
                        value: _date,
                        onChanged: (d) => setState(() => _date = d),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: const Icon(Icons.check),
                        label: Text(_kind == MovementKind.expense
                            ? 'Καταχώριση πληρωμής'
                            : 'Καταχώριση είσπραξης'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
