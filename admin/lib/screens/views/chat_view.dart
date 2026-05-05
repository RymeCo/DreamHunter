import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api_gateway.dart';
import '../../models/chat_message.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ApiGateway _api = ApiGateway();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  WebSocketChannel? _channel;
  List<ChatMessage> _messages = [];
  String _selectedRegion = 'english';
  bool _isConnected = false;

  final List<String> _regions = ['english', 'global', 'lobby', 'trade'];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (mounted) setState(() => _isConnected = false);
  }

  Future<void> _connect() async {
    _disconnect();
    
    final token = await _api.getIdToken();
    if (token == null) return;

    final wsUrl = ApiGateway.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final uri = Uri.parse('$wsUrl/ws/chat/$_selectedRegion?token=$token');
    
    try {
      _channel = WebSocketChannel.connect(uri);
      setState(() {
        _isConnected = true;
        _messages = [];
      });

      _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data);
          final message = ChatMessage.fromJson(json);
          setState(() {
            _messages.add(message);
            if (_messages.length > 100) _messages.removeAt(0);
          });
          _scrollToBottom();
        },
        onError: (err) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      setState(() => _isConnected = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _channel == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final message = ChatMessage(
      id: '',
      senderId: user?.uid ?? 'admin',
      senderName: 'Admin',
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.system,
      region: _selectedRegion,
    );

    _channel!.sink.add(jsonEncode(message.toJson()));
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header / Region Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Live Monitor:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedRegion,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRegion = val);
                    _connect();
                  }
                },
                items: _regions.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.toUpperCase()),
                )).toList(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isConnected 
                      ? Colors.green.withValues(alpha: 0.1) 
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isConnected ? Colors.green : Colors.red),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Message List
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('Waiting for messages...'),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isSystem = msg.type == MessageType.system || msg.type == MessageType.announcement;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                msg.senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSystem ? Colors.orange : Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSystem 
                                  ? Colors.orange.withValues(alpha: 0.05) 
                                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: isSystem ? Border.all(color: Colors.orange.withValues(alpha: 0.2)) : null,
                            ),
                            child: Text(msg.text),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        
        // Input Field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Send system message to region...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                onPressed: _isConnected ? _sendMessage : null,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
