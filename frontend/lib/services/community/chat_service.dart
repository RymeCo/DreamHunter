import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dreamhunter/models/chat_message.dart';
import 'package:dreamhunter/models/task_model.dart';
import 'package:dreamhunter/services/core/api_gateway.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/services/progression/task_service.dart';

class ChatService {
  static final ChatService instance = ChatService._internal();
  factory ChatService() => instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _messageBuffer = [];
  String? _currentRegion;
  bool _isConnecting = false;
  DateTime? _lastMessageTime;

  Stream<List<ChatMessage>> getMessages({String region = 'english'}) {
    // Reconnect if switching regions OR if the channel was closed/disconnected
    if (_currentRegion != region || _channel == null) {
      if (_currentRegion != region) {
        _messageBuffer.clear();
      }
      _currentRegion = region;
      
      // OPTIMIZATION: Push existing buffer immediately if we have it
      if (_messageBuffer.isNotEmpty) {
        developer.log('Pushing ${_messageBuffer.length} messages from cache immediately.', name: 'ChatService');
        Future.microtask(() => _messageController.add(List.from(_messageBuffer)));
      }
      
      _connect(region);
    } else {
      // Even if already connected, push current buffer to ensure the new listener gets data
      developer.log('Active channel found, pushing current buffer.', name: 'ChatService');
      Future.microtask(() => _messageController.add(List.from(_messageBuffer)));
    }
    return _messageController.stream;
  }

  void _connect(String region) async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      // Get the ID token for security
      developer.log('Fetching token for chat...', name: 'ChatService');
      final token = await ApiGateway().getIdToken();
      
      if (token == null) {
        developer.log('No token found, chat cannot connect.', name: 'ChatService');
        _isConnecting = false;
        return;
      }

      // Convert https://.../api to wss://.../api/ws/chat/region?token=...
      final wsUrl = ApiGateway.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      
      final uri = Uri.parse('$wsUrl/ws/chat/$region?token=$token');

      developer.log('Connecting to WebSocket: $uri', name: 'ChatService');
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          final message = ChatMessage.fromJson(json);
          
          // Deduplication: Only add if message ID isn't already in buffer
          if (!_messageBuffer.any((m) => m.id == message.id)) {
            _messageBuffer.add(message);
            
            // Sort by timestamp to ensure history and live messages are in order
            _messageBuffer.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            
            if (_messageBuffer.length > 50) {
              _messageBuffer.removeAt(0);
            }
            
            _messageController.add(List.from(_messageBuffer));
          }
        },
        onError: (error) {
          developer.log('WebSocket Error', error: error, name: 'ChatService');
          _reconnect(region);
        },
        onDone: () {
          developer.log('WebSocket Closed', name: 'ChatService');
          _reconnect(region);
        },
      );
      _isConnecting = false;
    } catch (e) {
      developer.log('WebSocket Connection Failed', error: e, name: 'ChatService');
      _isConnecting = false;
      _reconnect(region);
    }
  }

  void _reconnect(String region) {
    _isConnecting = false; // Reset flag so retry can proceed
    _channel = null; // Ensure channel is null so getMessages triggers reconnect
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentRegion == region) {
        _connect(region);
      }
    });
  }

  Future<void> sendMessage(String text, {String region = 'english'}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Rate Limiting: 5 second cooldown
    if (_lastMessageTime != null) {
      final diff = DateTime.now().difference(_lastMessageTime!);
      if (diff.inSeconds < 5) {
        throw Exception('Please wait ${5 - diff.inSeconds}s before chatting again.');
      }
    }

    final player = await ProfileManager.instance.getPlayer();
    if (player == null || player.isBannedFromChat || player.isMuted) return;

    final message = ChatMessage(
      id: '',
      senderId: user.uid,
      senderName: player.name,
      text: text,
      timestamp: DateTime.now(),
      region: region,
    );

    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message.toJson()));
      _lastMessageTime = DateTime.now();
      
      // Track task progress
      TaskService.instance.trackAction(TaskType.chat);
    } else {
      throw Exception('Chat is currently offline. Trying to reconnect...');
    }
  }

  /// Keep daily announcement on Firestore as it's a "cold" read (once a day).
  Future<Map<String, dynamic>?> getDailyAnnouncement() async {
    final lastShown = await StorageEngine.instance.getMetadata('last_announcement_info');
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastShown != null && lastShown['date'] == today) {
      return null;
    }

    try {
      // ADDED: 3 second timeout to Firestore read to prevent hanging on bad connections
      final doc = await _firestore
          .collection('metadata')
          .doc('announcements')
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists) {
        final data = doc.data()!;
        final announcement = {
          'date': today,
          'message': data['daily_message'] ?? 'Welcome to DreamHunter!',
          'rules': data['rules'] ?? [
            '1. Be respectful to others.',
            '2. No spamming or advertising.',
            '3. Keep it family friendly.',
          ],
        };

        await StorageEngine.instance.saveMetadata('last_announcement_info', {'date': today});
        return announcement;
      }
    } catch (e) {
      developer.log('Announcement fetch failed or timed out', error: e, name: 'ChatService');
      // Return default announcement so user isn't stuck waiting
      return {
        'date': today,
        'message': 'Welcome to DreamHunter! Stay tuned for daily updates.',
        'rules': ['Respect others.', 'No spam.', 'Have fun!'],
      };
    }
    return null;
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    // We DON'T clear _currentRegion or _messageBuffer here anymore.
    // This allows the UI to show "cached" messages immediately next time.
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
