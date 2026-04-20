import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

/// Minimalist Singleton service for Firebase Authentication.
class AuthManager {
  // Singleton Pattern
  static final AuthManager instance = AuthManager._internal();
  AuthManager._internal();
  factory AuthManager() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in with email and password.
  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Register a new user and update their display name.
  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);
    return cred;
  }

  /// Sign out and clear local cache.
  Future<void> signOut() async {
    await StorageEngine.instance.clearAllUserData();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
