import 'dart:async';

import 'package:flutter/material.dart';

import '../data/instrument_search.dart';
import '../models/holding.dart';

/// Αναζήτηση μετοχής / ETF. Επιστρέφει το [Instrument] που επιλέχθηκε
/// (ή ένα χειροκίνητο, με μόνο σύμβολο, αν δεν βρεθεί στη λίστα).
class InstrumentSearchScreen extends StatefulWidget {
  const InstrumentSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<InstrumentSearchScreen> createState() => _InstrumentSearchScreenState();
}

class _InstrumentSearchScreenState extends State<InstrumentSearchScreen> {
  final _search = InstrumentSearch();
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<Instrument> _online = const [];
  bool _loading = false;
  String? _error;

  /// Αυξάνεται σε κάθε αναζήτηση, για να αγνοούνται παλιές απαντήσεις.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _runOnline();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runOnline);
  }

  Future<void> _runOnline() async {
    final q = _query.text.trim();
    final id = ++_requestId;
    if (q.length < 2) {
      setState(() {
        _online = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _search.searchOnline(q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _online = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _online = const [];
        _loading = false;
        _error = 'Η online αναζήτηση απέτυχε. Δοκίμασε ξανά σε λίγο.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final popular = InstrumentSearch.searchPopular(q);
    final popularKeys = {for (final i in popular) i.key};
    final online = _online.where((i) => !popularKeys.contains(i.key)).toList();
    final text = Theme.of(context).textTheme;

    Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title,
              style: text.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Σύμβολο ή όνομα (π.χ. AAPL, apple, VWCE)',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (q.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Χρήση «${q.toUpperCase()}» χωρίς αναζήτηση'),
                  subtitle: const Text('Αν δεν βρίσκεις το προϊόν στη λίστα'),
                  onTap: () => Navigator.of(context).pop(Instrument(
                      q.toUpperCase(), '', '', 'EUR', AssetType.stock)),
                ),
              if (popular.isNotEmpty) ...[
                header(q.isEmpty ? 'Δημοφιλή' : 'Από τα δημοφιλή'),
                for (final i in popular) _InstrumentTile(instrument: i),
              ],
              if (q.length >= 2) header('Αποτελέσματα αναζήτησης'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                )
              else if (q.length >= 2 && online.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Δεν βρέθηκαν άλλα αποτελέσματα.'),
                )
              else
                for (final i in online) _InstrumentTile(instrument: i),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  const _InstrumentTile({required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final i = instrument;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          i.symbol.isEmpty ? '?' : i.symbol.substring(0, 1),
        ),
      ),
      title: Text(i.symbol),
      subtitle: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        [i.type.label, if (i.exchange.isNotEmpty) i.exchange, i.currency]
            .join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => Navigator.of(context).pop(i),
    );
  }
}
