<p align="center">
  <img src="assets/branding/logo_full.png" alt="MyInvest" width="320">
</p>

# MyInvest

Εφαρμογή προσωπικών οικονομικών για **Android** και **Web**, φτιαγμένη με **Flutter** και **Firebase**.
Συγκεντρώνει σε ένα σημείο τραπεζικούς λογαριασμούς, επενδύσεις, λογαριασμούς trading και δανεικά,
με αυτόματες τιμές, μετατροπή νομισμάτων και γραφήματα.

*A personal finance tracker for Android and Web built with Flutter and Firebase: bank accounts,
investment portfolio with live prices, trading accounts, loans, transfers and visual analytics.*

## Λειτουργίες

- **Λογαριασμοί**: τράπεζες (Alpha Bank, Εθνική, Revolut, FP Trading κ.ά.), ρευστό, επενδυτικοί και trading λογαριασμοί.
- **Καθαρή περιουσία** σε ευρώ, με κατανομή ανά κατηγορία και ανά τράπεζα, και ημερήσιο ιστορικό.
- **Επενδύσεις**: αγορές/πωλήσεις με προμήθειες, μέση τιμή κτήσης, ανοιχτό και πραγματοποιημένο κέρδος.
- **Αναζήτηση μετοχών & ETF** (δημοφιλή offline + online αναζήτηση σε όλα τα χρηματιστήρια).
- **Αυτόματες τιμές**: Yahoo Finance (Android, και στο παρασκήνιο κάθε ~15'), CoinGecko για crypto.
- **Πολλαπλά νομίσματα** με ισοτιμίες της ΕΚΤ (Frankfurter).
- **Γρήγορη πληρωμή / είσπραξη**: ποσό και λογαριασμός, και το υπόλοιπο ενημερώνεται αυτόματα.
- **Μεταφορές** μεταξύ λογαριασμών· κοινό ιστορικό κινήσεων με αναίρεση.
- **Δανεικά**: τι χρωστάνε, επιστροφές, εξόφληση.
- **Αναλύσεις** με γραφήματα (κατανομές, κέρδος/ζημιά ανά θέση, αγορές ανά μήνα, εξέλιξη περιουσίας)
  και εναλλακτική προβολή σε πίνακες.
- **Απόκρυψη συνόλων** με ένα κουμπί («ματάκι»): κρύβει την καθαρή περιουσία και τα συγκεντρωτικά ποσά
  όταν η οθόνη φαίνεται σε άλλους, ενώ οι λογαριασμοί παραμένουν ορατοί. Η επιλογή αποθηκεύεται ανά συσκευή.
- Σύνδεση με email/κωδικό· κάθε χρήστης βλέπει μόνο τα δικά του δεδομένα.

## Τεχνολογίες

| | |
|---|---|
| Εφαρμογή | Flutter (Dart), Material 3, φωτεινό/σκούρο θέμα |
| Backend | Firebase Authentication, Cloud Firestore (offline cache), Firebase Hosting |
| Γραφήματα | fl_chart + δικά μου widgets |
| Παρασκήνιο | WorkManager (Android) |
| Δεδομένα αγοράς | Yahoo Finance, CoinGecko, Twelve Data (αναζήτηση), Frankfurter (ΕΚΤ) |

## Δομή

```
lib/
  models/       Λογαριασμοί, θέσεις & συναλλαγές, μεταφορές
  data/         Firestore repositories, τιμές, ισοτιμίες, αναζήτηση
  screens/      Οθόνες της εφαρμογής
  widgets/      Γραφήματα και οπτικά στοιχεία
  background/   Ανανέωση τιμών στο παρασκήνιο
test/           Unit & widget tests
```

## Εκτέλεση

Οι ρυθμίσεις Firebase του δικού μου project **δεν** περιλαμβάνονται στο αποθετήριο.
Για να τρέξεις την εφαρμογή χρειάζεσαι δικό σου (δωρεάν) Firebase project:

1. Φτιάξε project στο [Firebase](https://console.firebase.google.com), με **Firestore** και
   **Authentication → Email/Password**.
2. Εγκατέστησε τα εργαλεία και σύνδεσε το project:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android,web
   ```
   Δημιουργούνται τα `lib/firebase_options.dart` και `android/app/google-services.json`.
3. Ανέβασε τους κανόνες ασφαλείας: `firebase deploy --only firestore:rules`
4. Τρέξε: `flutter run`

Tests: `flutter test`

## Ασφάλεια

Οι κανόνες του Firestore ([firestore.rules](firestore.rules)) επιτρέπουν σε κάθε χρήστη πρόσβαση
μόνο στα δικά του δεδομένα (`users/{uid}/...`). Κωδικοί και κλειδιά δεν αποθηκεύονται στον κώδικα.

---

© Σαράντης Τσιουμλέκης
