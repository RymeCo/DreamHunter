import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'backend_service.dart';
import 'offline_cache.dart';

/// A centralized service for managing authentication and Firebase interactions.
///
/// ### How to use:
/// ```dart
/// final AuthService _auth = AuthService();
///
/// // Sign in
/// await _auth.signIn(email, password);
///
/// // Register
/// await _auth.register(
///   email: email,
///   password: password,
///   displayName: displayName,
/// );
///
/// // Sign out
/// await _auth.signOut();
/// ```
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BackendService _backend = BackendService();

  /// Sign in with email and password
  Future<UserCredential> signIn(String email, String password) async {
    developer.log('Attempting sign in for $email', name: 'AuthService');
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    developer.log('Sign in successful, migrating guest data...', name: 'AuthService');
    // Migrate guest data to this user
    await OfflineCache.migrateGuestData(userCredential.user!.uid);
    
    developer.log('Syncing user profile with backend...', name: 'AuthService');
    // Sync with FastAPI backend and update local cache
    final profile = await _backend.syncUserProfile();
    if (profile != null) {
      await OfflineCache.saveCurrency(
        profile['dreamCoins'] ?? 0,
        profile['hellStones'] ?? 0,
        profile['playtime'] ?? 0,
        profile['freeSpins'] ?? 0,
        profile['xp'] ?? 0,
        profile['level'] ?? 1,
        profile['avatarId'] ?? 0,
        profile['createdAt'] as String?,
        profile['dailyTasks'] as Map<String, dynamic>?,
        true, // forceUpdate = true
      );
    }
    
    return userCredential;
  }

  /// Register new user with display name and Firestore record
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // 1. Check if display name is already taken using a query
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

    // 2. Create the Auth account
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 3. Update Auth display name
    await userCredential.user?.updateDisplayName(displayName);

    // 4. Centralized Registration via FastAPI
    // This handles playerNumber, initial currency, and metadata
    developer.log('Registering user with backend...', name: 'AuthService');
    try {
      final profile = await _backend.post('/user/register');
      if (profile.statusCode != 200) {
         throw Exception('Backend registration failed: ${profile.body}');
      }
      
      final data = json.decode(profile.body);
      // Cache the initial profile data
      await OfflineCache.saveCurrency(
        data['dreamCoins'] ?? 500,
        data['hellStones'] ?? 10,
        0, // playtime
        1, // freeSpins
        0, // xp
        1, // level
        0, // avatarId
        data['createdAt'] as String?,
        null, // dailyTasks (will be pulled on next sync)
        true,
      );
    } catch (e) {
      developer.log('Backend registration error', error: e, name: 'AuthService');
      // If registration fails, we should technically delete the auth user or handle retry
      rethrow;
    }

    // Sync with FastAPI backend after registration
    developer.log('Initial sync with backend after registration...', name: 'AuthService');
    try {
      await _backend.syncUserProfile().timeout(const Duration(seconds: 10));
    } catch (e) {
      developer.log('Initial sync failed during registration, proceeding...', 
          error: e, name: 'AuthService');
    }
    
    // Move any guest transactions to this user before signing out (to be synced later on first login)
    developer.log('Migrating guest data to new user ${userCredential.user!.uid}...', name: 'AuthService');
    try {
      await OfflineCache.migrateGuestData(userCredential.user!.uid);
    } catch (e) {
      developer.log('Guest migration failed during registration', 
          error: e, name: 'AuthService');
    }

    developer.log('Registration complete, signing out...', name: 'AuthService');
    // Sign out to force manual login
    await signOut();
  }

  /// Log out
  Future<void> signOut() async {
    // 1. Final cloud sync to ensure local progress is backed up
    try {
      await _backend.performFullSync();
    } catch (e) {
      // We still want to log out even if sync fails (e.g. offline)
      developer.log('Final sync failed during logout', error: e, name: 'AuthService');
    }

    // 2. Clear local cache for this user before signing out
    await OfflineCache.clearAllUserData();
    await _auth.signOut();
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
