import 'package:flutter/material.dart';

import '../utils/privacy.dart';

/// Κουμπί-«ματάκι» για την πάνω μπάρα: κρύβει ή εμφανίζει όλα τα ποσά.
class PrivacyToggleButton extends StatelessWidget {
  const PrivacyToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hideAmounts,
      builder: (context, hidden, _) => IconButton(
        tooltip: hidden ? 'Εμφάνιση ποσών' : 'Απόκρυψη ποσών',
        icon: Icon(hidden
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        onPressed: toggleHideAmounts,
      ),
    );
  }
}
