import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'offline_cache.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> signIn(String email, String password) async {
    developer.log('Attempting sign in for $email', name: 'AuthService');
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential;
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final querySnapshot = await _db
        .collection('users')
        .where('displayName', isEqualTo: displayName)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'display-name-taken',
        message: 'This display name is already in use.',
      );
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user?.updateDisplayName(displayName);
    
    await signOut();
  }

  Future<void> signOut() async {
    await OfflineCache.clearAllUserData();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
