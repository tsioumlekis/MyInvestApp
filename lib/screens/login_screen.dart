import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Σύνδεση / εγγραφή με email και κωδικό.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (_register) {
        await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Γράψε πρώτα το email σου.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Στάλθηκε email επαναφοράς κωδικού.'),
      ));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _messageFor(e));
    }
  }

  String _messageFor(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'Μη έγκυρο email.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Λάθος email ή κωδικός.',
      'email-already-in-use' => 'Υπάρχει ήδη λογαριασμός με αυτό το email.',
      'weak-password' => 'Ο κωδικός είναι πολύ αδύναμος (τουλάχιστον 6 χαρακτήρες).',
      'operation-not-allowed' =>
        'Η σύνδεση με email δεν είναι ενεργή στο Firebase.',
      'network-request-failed' => 'Δεν υπάρχει σύνδεση στο internet.',
      'too-many-requests' => 'Πολλές προσπάθειες. Δοκίμασε ξανά σε λίγο.',
      _ => 'Σφάλμα: ${e.message ?? e.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Λογότυπο σε λευκή κάρτα, ώστε να φαίνεται και στο σκούρο θέμα.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/branding/logo_full.png',
                        height: 180,
                        fit: BoxFit.contain,
                        semanticLabel: 'MyInvest',
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Συμπλήρωσε έγκυρο email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Κωδικός'),
                      obscureText: true,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Τουλάχιστον 6 χαρακτήρες'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Εγγραφή' : 'Σύνδεση'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _register = !_register;
                                _error = null;
                              }),
                      child: Text(_register
                          ? 'Έχεις ήδη λογαριασμό; Σύνδεση'
                          : 'Δεν έχεις λογαριασμό; Εγγραφή'),
                    ),
                    if (!_register)
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Ξέχασα τον κωδικό'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
