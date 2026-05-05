import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api_gateway.dart';
import '../../models/chat_message.dart';
import '../../utils/formatters.dart';
import 'player_edit_dialog.dart';

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
  String _selectedRegion = 'global';
  bool _isConnected = false;
  bool _isDisposed = false;

  final Set<String> _censoredMessages = {};

  final List<String> _regions = [
    'global',
    'english',
    'tagalog',
    'chinese',
    'russian',
    'spanish',
  ];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (mounted && !_isDisposed) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _connect() async {
    _disconnect();

    final token = await _api.getIdToken();
    if (token == null || !mounted || _isDisposed) return;

    final wsUrl = ApiGateway.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final uri = Uri.parse('$wsUrl/ws/chat/$_selectedRegion?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      if (mounted && !_isDisposed) {
        setState(() {
          _isConnected = true;
          _messages = [];
        });
      }

      _channel!.stream.listen(
        (data) {
          if (!mounted || _isDisposed) return;
          final json = jsonDecode(data);
          
          if (json['type'] == 'delete') {
            final targetId = json['targetId'];
            setState(() {
              _messages.removeWhere((m) => m.id == targetId);
            });
            return;
          }

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
    if (mounted && !_isDisposed) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _censorMessageGlobal(String messageId) async {
    if (_channel == null) return;
    
    final payload = {
      'type': 'delete',
      'targetId': messageId,
    };
    
    _channel!.sink.add(jsonEncode(payload));
  }

  void _showModerationMenu(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Censor Globally', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Remove message for ALL players'),
                onTap: () {
                  _censorMessageGlobal(message.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: Text(
                  _censoredMessages.contains(message.id)
                      ? 'Unhide Locally'
                      : 'Hide Locally',
                ),
                subtitle: const Text('Hide only for your admin view'),
                onTap: () {
                  setState(() {
                    if (_censoredMessages.contains(message.id)) {
                      _censoredMessages.remove(message.id);
                    } else {
                      _censoredMessages.add(message.id);
                    }
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_search),
                title: Text('Manage ${message.senderName}'),
                subtitle: const Text('View and edit player profile'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditPlayer(message.senderId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditPlayer(String uid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _api.get('/admin/players/$uid');
      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final player = json.decode(response.body);
        _showEditDialog(player);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch player details: $e')),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return PlayerEditDialog(
          player: player,
          onUpdate: (updatedData) async {
            if (!dialogContext.mounted) return;

            final confirm = await showDialog<bool>(
              context: dialogContext,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Changes'),
                content: const Text(
                  'Apply these changes to the player profile?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Apply',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                final response = await _api.patch(
                  '/admin/players/${player['uid']}',
                  body: updatedData,
                );
                if (dialogContext.mounted && response.statusCode == 200) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Player updated successfully!'),
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                }
              }
            }
          },
        );
      },
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        // Region & Status Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.public, size: 20),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedRegion,
                underline: const SizedBox(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRegion = val);
                    _connect();
                  }
                },
                items: _regions
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.toUpperCase()),
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              _ConnectionStatusChip(isConnected: _isConnected),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No activity in ${_selectedRegion.toUpperCase()}',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isSystem =
                        msg.type == MessageType.system ||
                        msg.type == MessageType.announcement;
                    final isCensored = _censoredMessages.contains(msg.id);

                    return _ChatMessageTile(
                      message: msg,
                      isSystem: isSystem,
                      isCensored: isCensored,
                      onTap: () => _showModerationMenu(msg),
                    );
                  },
                ),
        ),

        // Input Area
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Broadcast as ADMIN...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
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

class _ConnectionStatusChip extends StatelessWidget {
  final bool isConnected;
  const _ConnectionStatusChip({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isSystem;
  final bool isCensored;
  final VoidCallback onTap;

  const _ChatMessageTile({
    required this.message,
    required this.isSystem,
    required this.isCensored,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSystem 
                ? Colors.orange.withValues(alpha: 0.05) 
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSystem 
                  ? Colors.orange.withValues(alpha: 0.2) 
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSystem ? Colors.orange : colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppFormatters.formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isCensored ? 'Content hidden by moderator' : message.text,
                style: TextStyle(
                  fontStyle: isCensored ? FontStyle.italic : FontStyle.normal,
                  color: isCensored ? colorScheme.outline : colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
