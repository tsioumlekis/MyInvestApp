import 'package:flutter/material.dart';

import '../models/account.dart';
import 'charts.dart';
import 'visual.dart';

/// Σταθερό χρώμα ανά τράπεζα/πλατφόρμα (το χρώμα ακολουθεί την οντότητα).
/// Η σειρά των θέσεων είναι ελεγμένη για αχρωματοψία όταν εμφανίζονται
/// διαδοχικά (π.χ. στη μπάρα «Ανά τράπεζα»).
int institutionSlot(Account a) => a.type == AccountType.lent
    ? 4
    : switch (a.institution) {
        Institution.alphaBank => 0,
        Institution.nbg => 1,
        Institution.revolut => 2,
        Institution.other => 3,
        Institution.fpTrading => 5,
      };

String institutionName(Account a) =>
    a.type == AccountType.lent ? 'Δανεικά' : a.institution.label;

/// Στρογγυλό σήμα λογαριασμού στο χρώμα της τράπεζάς του.
Widget accountBadge(BuildContext context, Account a, {double size = 40}) {
  final color = seriesColor(context, institutionSlot(a));
  if (a.type == AccountType.lent) {
    return EntityBadge(color: color, icon: Icons.handshake_outlined, size: size);
  }
  final label = switch (a.institution) {
    Institution.alphaBank => 'A',
    Institution.nbg => 'ΕΤ',
    Institution.revolut => 'R',
    Institution.fpTrading => 'FP',
    Institution.other => a.name,
  };
  return EntityBadge(color: color, label: label, size: size);
}
