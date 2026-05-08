import 'dart:async';
import 'dart:convert';
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

      // OPTIMIZATION: Always push the current buffer (even if empty) to avoid the UI spinner
      Future.microtask(() => _messageController.add(List.from(_messageBuffer)));

      _connect(region);
    } else {
      // Even if already connected, push current buffer to ensure the new listener gets data
      Future.microtask(() => _messageController.add(List.from(_messageBuffer)));
    }
    return _messageController.stream;
  }

  void _connect(String region) async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      // 1. Get the ID token with a timeout to prevent hanging
      final token = await ApiGateway().getIdToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return null;
        },
      );

      // SECURITY: If the user switched regions while we were fetching the token,
      // we must abort this connection attempt to avoid region cross-talk.
      if (_currentRegion != region) {
        _isConnecting = false;
        return;
      }

      if (token == null) {
        _isConnecting = false;
        return;
      }

      // 2. Prepare WebSocket URL
      final wsUrl = ApiGateway.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final uri = Uri.parse('$wsUrl/ws/chat/$region?token=$token');

      // 3. Connect to WebSocket
      final channel = WebSocketChannel.connect(uri);

      // Assign to _channel before listening so sendMessage can potentially use it immediately
      _channel = channel;

      channel.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);

            // Handle global message deletion (Censorship)
            if (json['type'] == 'delete') {
              final targetId = json['targetId'];
              _messageBuffer.removeWhere((m) => m.id == targetId);
              _messageController.add(List.from(_messageBuffer));
              return;
            }

            if (json['type'] == 'clear') {
              _messageBuffer.clear();
              _messageController.add(List.from(_messageBuffer));
              return;
            }

            final message = ChatMessage.fromJson(json);

            // Deduplication
            if (!_messageBuffer.any((m) => m.id == message.id)) {
              _messageBuffer.add(message);
              _messageBuffer.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              if (_messageBuffer.length > 50) _messageBuffer.removeAt(0);

              _messageController.add(List.from(_messageBuffer));
            }
          } catch (e) {
            // Error decoding message
          }
        },
        onError: (error) {
          if (_currentRegion == region) _reconnect(region);
        },
        onDone: () {
          if (_currentRegion == region) _reconnect(region);
        },
      );

      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      if (_currentRegion == region) _reconnect(region);
    }
  }

  void _reconnect(String region) {
    _isConnecting = false;
    _channel = null;
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentRegion == region && _channel == null) {
        _connect(region);
      }
    });
  }

  Future<void> sendMessage(String text, {String region = 'english'}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to chat.');
    }

    // Rate Limiting: 5 second cooldown
    if (_lastMessageTime != null) {
      final diff = DateTime.now().difference(_lastMessageTime!);
      if (diff.inSeconds < 5) {
        throw Exception(
          'Please wait ${5 - diff.inSeconds}s before chatting again.',
        );
      }
    }

    var player = await ProfileManager.instance.getPlayer();
    if (player == null) {
      throw Exception('Failed to load player profile. Please try again.');
    }

    // REPAIR: If the local cache thinks we are muted/banned, force a refresh from the backend
    // to see if an admin has lifted the restriction "immediately".
    if (player.isBannedFromChat || player.isMuted) {
      player = await ProfileManager.instance.getPlayer(forceRefresh: true);
      if (player == null) throw Exception('Failed to verify profile status.');
    }

    if (player.isBannedFromChat) {
      throw Exception('You are banned from chat.');
    }

    if (player.isMuted) {
      final until = player.muteUntil != null
          ? DateTime.tryParse(player.muteUntil!)?.toLocal()
          : null;

      if (until != null) {
        final hours = until.difference(DateTime.now()).inHours;
        final mins = until.difference(DateTime.now()).inMinutes % 60;
        throw Exception('You are muted for another ${hours}h ${mins}m.');
      }
      throw Exception('You are currently muted.');
    }

    final message = ChatMessage(
      id: '',
      senderId: user.uid,
      senderName: player.name,
      text: text,
      timestamp: DateTime.now(),
      region: region,
    );

    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message.toJson()));
        _lastMessageTime = DateTime.now();

        // Track task progress
        TaskService.instance.trackAction(TaskType.chat);
      } catch (e) {
        _channel = null; // Mark as dead
        throw Exception('Connection lost. Reconnecting...');
      }
    } else {
      // If channel is null, we might be connecting or disconnected.
      // Trigger a connection if not already connecting.
      if (!_isConnecting) {
        _connect(region);
      }
      throw Exception('Chat is connecting. Please try again in a moment.');
    }
  }

  /// Keep daily announcement on Firestore as it's a "cold" read (once a day).
  Future<Map<String, dynamic>?> getDailyAnnouncement() async {
    final lastShown = await StorageEngine.instance.getMetadata(
      'last_announcement_info',
    );
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
          'rules':
              data['rules'] ??
              [
                '1. Be respectful to others.',
                '2. No spamming or advertising.',
                '3. Keep it family friendly.',
              ],
        };

        await StorageEngine.instance.saveMetadata('last_announcement_info', {
          'date': today,
        });
        return announcement;
      }
    } catch (e) {
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
