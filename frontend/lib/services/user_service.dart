import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns a stream of the current user's document for real-time UI updates (e.g. currency)
  Stream<DocumentSnapshot> getUserStats() {
    final user = _auth.currentUser;
    if (user == null) {
      // Return an empty stream if not logged in
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
  }

  /// Fetches a list of shop items from Firestore
  Stream<QuerySnapshot> getShopItems() {
    return _db.collection('shop_items').snapshots();
  }
}
