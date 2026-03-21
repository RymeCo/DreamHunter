import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Migrate guest data to this user
    await OfflineCache.migrateGuestData(userCredential.user!.uid);
    
    // Sync with FastAPI backend and update local cache
    final profile = await _backend.syncUserProfile();
    if (profile != null) {
      await OfflineCache.saveCurrency(
        profile['dreamCoins'] ?? 0,
        profile['hellStones'] ?? 0,
        profile['playtime'] ?? 0,
        profile['freeSpins'] ?? 0,
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

    // 4. Use a Transaction for the global counter and user document
    final counterRef = _db.collection('metadata').doc('counters');
    final userRef = _db.collection('users').doc(userCredential.user!.uid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot counterDoc = await transaction.get(counterRef);
      int newPlayerNumber = 1;

      if (counterDoc.exists) {
        newPlayerNumber = (counterDoc.get('totalPlayers') ?? 0) + 1;
      }

      // Update global counter
      transaction.set(
        counterRef,
        {'totalPlayers': newPlayerNumber},
        SetOptions(merge: true),
      );

      // Create the user profile
      transaction.set(userRef, {
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': displayName,
        'playerNumber': newPlayerNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'saveSlots': {'slot1': null, 'slot2': null, 'slot3': null},
        'isBanned': false,
        'mutedUntil': null,
        'isAdmin': false,
        'dreamCoins': 500,
        'hellStones': 10,
        'inventory': [],
      });
    });

    // Sync with FastAPI backend after registration
    await _backend.syncUserProfile();
    
    // Move any guest transactions to this user before signing out (to be synced later on first login)
    await OfflineCache.migrateGuestData(userCredential.user!.uid);

    // Sign out to force manual login
    await signOut();
  }

  /// Log out
  Future<void> signOut() async {
    // Clear local cache for this user before signing out
    await OfflineCache.clearAllUserData();
    await _auth.signOut();
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
