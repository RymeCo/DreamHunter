import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api_gateway.dart';
import '../../models/chat_message.dart';
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Live Monitor:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
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

        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                    final isSystem =
                        msg.type == MessageType.system ||
                        msg.type == MessageType.announcement;
                    final isCensored = _censoredMessages.contains(msg.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _showModerationMenu(msg),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    msg.senderName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSystem
                                          ? Colors.orange
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                  if (isCensored)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSystem
                                      ? Colors.orange.withValues(alpha: 0.05)
                                      : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSystem
                                      ? Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.2,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Text(
                                  isCensored
                                      ? 'Content hidden by moderator'
                                      : msg.text,
                                  style: TextStyle(
                                    fontStyle: isCensored
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    color: isCensored
                                        ? Colors.grey
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
