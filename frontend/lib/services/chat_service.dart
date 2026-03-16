import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'backend_service.dart';

class ChatService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final BackendService _backend;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    BackendService? backend,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _backend = backend ?? BackendService();

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

  /// Sends a message to the FastAPI backend (enforces 1s cooldown and 100-msg limit)
  Future<bool> sendMessage(String region, String text) async {
    final user = _auth.currentUser;
    if (user == null) return false; // Guests cannot send
    
    try {
      final device = await getDeviceInfo();

      final response = await _backend.post(
        '/chats/$region/messages',
        body: {
          'text': text,
          'senderDevice': device,
        },
      );

      // 429 means Spam Cooldown hit
      if (response.statusCode == 429) {
        throw Exception('cooldown');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (e.toString().contains('cooldown')) rethrow;
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Submits a report with full evidence to the public FastAPI endpoint
  Future<bool> reportMessage({
    required String messageId,
    required String originalMessageText,
    required String senderId,
    required String senderDevice,
    required String messageTimestamp,
    required List<String> categories,
    String? reporterEmail,
  }) async {
    try {
      final reporterId = await getActiveId();

      // Use an unauthenticated client for reports if guest, but BackendService
      // uses authenticated if available. Reports endpoint is public anyway.
      final response = await _backend.post(
        '/reports',
        body: {
          'reportedMessageId': messageId,
          'originalMessageText': originalMessageText,
          'senderId': senderId,
          'senderDevice': senderDevice,
          'reporterId': reporterId,
          'messageTimestamp': messageTimestamp,
          'categories': categories,
          'reporterEmail': reporterEmail,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return false;
    }
  }

  /// Like a message directly in Firestore using a transaction to prevent duplicates.
  Future<void> likeMessage(String region, String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return; // Guests cannot like

    final msgRef = _db.collection('chats').doc(region).collection('messages').doc(messageId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final List<dynamic> likedBy = data['likedBy'] ?? [];

      if (likedBy.contains(user.uid)) {
        // User already liked, so unlike
        transaction.update(msgRef, {
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid])
        });
      } else {
        // User hasn't liked yet
        transaction.update(msgRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid])
        });
      }
    });
  }
}
