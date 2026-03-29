import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ChatService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? _cachedGuestId;
  String? _cachedDeviceInfo;

  /// Retrieves or generates a persistent guest ID for this device.
  Future<String> getGuestId() async {
    if (_cachedGuestId != null) return _cachedGuestId!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('guest_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('guest_id', id);
    }
    _cachedGuestId = id;
    return id;
  }

  /// Retrieves basic, non-invasive device info (e.g., "iPhone 13", "Android 13").
  Future<String> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) return _cachedDeviceInfo!;

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String info = 'Unknown Device';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        info = 'Web (${webInfo.browserName.name})';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info = 'Android (${androidInfo.model})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info = 'iOS (${iosInfo.utsname.machine})';
      } else if (Platform.isWindows) {
        info = 'Windows';
      } else if (Platform.isLinux) {
        info = 'Linux';
      } else if (Platform.isMacOS) {
        info = 'MacOS';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    _cachedDeviceInfo = info;
    return info;
  }

  /// Retrieves the last selected region, defaulting to 'english'.
  Future<String> getSelectedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_chat_region') ?? 'english';
  }

  /// Saves the selected region to SharedPreferences.
  Future<void> setSelectedRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_chat_region', region);
  }

  /// Get the active user ID (either Firebase UID or Guest UUID)
  Future<String> getActiveId() async {
    return _auth.currentUser?.uid ?? await getGuestId();
  }

  /// Streams the current system configuration (maintenance modes).
  Stream<DocumentSnapshot> getSystemConfig() {
    return _db.collection('metadata').doc('system_config').snapshots();
  }

  /// Streams the latest global alert/broadcast message.
  Stream<DocumentSnapshot> getGlobalAlert() {
    return _db.collection('metadata').doc('global_alert').snapshots();
  }

  /// Stream messages from a specific region, limited to the latest 100.
  Stream<QuerySnapshot> getChatStream(String region) {
    return _db
        .collection('chats')
        .doc(region)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Sends a message (Offline mode)
  Future<Map<String, dynamic>?> sendMessage(String region, String text) async {
    return {'status': 'success', 'message': 'Message sent (Offline mode)'};
  }

  /// Submits a report (Offline mode)
  Future<bool> reportMessage({
    required String messageId,
    required String originalMessageText,
    required String senderId,
    required String senderDevice,
    required String messageTimestamp,
    required List<String> categories,
    String? reporterEmail,
  }) async {
    return true;
  }

  /// Like a message directly in Firestore using a transaction to prevent duplicates.
  Future<void> likeMessage(String region, String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return; // Guests cannot like

    final msgRef = _db
        .collection('chats')
        .doc(region)
        .collection('messages')
        .doc(messageId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final List<dynamic> likedBy = data['likedBy'] ?? [];

      if (likedBy.contains(user.uid)) {
        // User already liked, so unlike
        transaction.update(msgRef, {
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        // User hasn't liked yet
        transaction.update(msgRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
      }
    });
  }
}
