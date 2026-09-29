import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/transfer.dart';

/// Πρόσβαση στους λογαριασμούς ενός χρήστη στο Firestore:
/// `users/{uid}/accounts/{accountId}`.
/// Το Firestore κρατά τοπική cache, οπότε η εφαρμογή δουλεύει και offline.
class AccountRepository {
  AccountRepository(this.uid, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _collection = (firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(uid)
            .collection('accounts'),
        _transfers = (firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(uid)
            .collection('transfers');

  final String uid;
  final FirebaseFirestore _db;
  final CollectionReference<Map<String, dynamic>> _collection;
  final CollectionReference<Map<String, dynamic>> _transfers;

  /// Μεταφορές, πιο πρόσφατες πρώτα.
  Stream<List<Transfer>> watchTransfers() {
    return _transfers.orderBy('date', descending: true).snapshots().map(
        (s) => [for (final d in s.docs) Transfer.fromMap(d.id, d.data())]);
  }

  /// Μεταφέρει χρήματα: μειώνει τον έναν λογαριασμό, αυξάνει τον άλλο και
  /// καταγράφει τη μεταφορά, όλα μαζί (batch). Χρησιμοποιεί increment,
  /// ώστε να δουλεύει σωστά και offline.
  Future<void> transfer({
    required Account from,
    required Account to,
    required int amountCents,
    required int toAmountCents,
    String note = '',
  }) {
    final ref = _transfers.doc();
    final now = DateTime.now();
    final transfer = Transfer(
      id: ref.id,
      fromId: from.id,
      toId: to.id,
      amountCents: amountCents,
      currency: from.currency,
      toAmountCents: toAmountCents,
      toCurrency: to.currency,
      date: now,
      note: note,
    );
    return (_db.batch()
          ..update(_collection.doc(from.id), {
            'balanceCents': FieldValue.increment(-amountCents),
            'updatedAt': now.toIso8601String(),
          })
          ..update(_collection.doc(to.id), {
            'balanceCents': FieldValue.increment(toAmountCents),
            'updatedAt': now.toIso8601String(),
          })
          ..set(ref, transfer.toMap()))
        .commit();
  }

  /// Αναιρεί μια μεταφορά: επιστρέφει τα ποσά και διαγράφει την εγγραφή.
  /// Λογαριασμοί που έχουν διαγραφεί στο μεταξύ παραλείπονται.
  Future<void> undoTransfer(Transfer t, {required Set<String> existingIds}) {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    if (existingIds.contains(t.fromId)) {
      batch.update(_collection.doc(t.fromId), {
        'balanceCents': FieldValue.increment(t.amountCents),
        'updatedAt': now,
      });
    }
    if (existingIds.contains(t.toId)) {
      batch.update(_collection.doc(t.toId), {
        'balanceCents': FieldValue.increment(-t.toAmountCents),
        'updatedAt': now,
      });
    }
    batch.delete(_transfers.doc(t.id));
    return batch.commit();
  }

  Stream<List<Account>> watchAll() {
    return _collection.snapshots().map((snapshot) {
      final accounts = snapshot.docs
          .map((doc) => Account.fromMap({...doc.data(), 'id': doc.id}))
          .toList()
        ..sort((a, b) {
          final byInstitution =
              a.institution.index.compareTo(b.institution.index);
          return byInstitution != 0 ? byInstitution : a.name.compareTo(b.name);
        });
      return accounts;
    });
  }

  Future<void> add({
    required String name,
    required Institution institution,
    required AccountType type,
    required String currency,
    required int balanceCents,
    String note = '',
  }) {
    final doc = _collection.doc();
    final account = Account(
      id: doc.id,
      name: name,
      institution: institution,
      type: type,
      currency: currency,
      balanceCents: balanceCents,
      updatedAt: DateTime.now(),
      note: note,
    );
    return doc.set(account.toMap());
  }

  Future<void> save(Account account) =>
      _collection.doc(account.id).set(account.toMap());

  Future<void> updateBalance(Account account, int balanceCents) {
    return save(account.copyWith(
      balanceCents: balanceCents,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}
