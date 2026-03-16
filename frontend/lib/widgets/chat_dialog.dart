import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/chat_service.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/report_dialog.dart';
import 'package:dreamhunter/widgets/login_dialog.dart';
import 'package:dreamhunter/widgets/register_dialog.dart';

enum _ChatAuthDialogType { login, register }

class ChatDialog extends StatefulWidget {
  final ChatService? chatService;
  const ChatDialog({super.key, this.chatService});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  late final ChatService _chatService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _selectedRegion = 'english';
  
  final Map<String, String> _regions = {
    'english': '🇺🇸 English',
    'spanish': '🇪🇸 Español',
    'chinese': '🇨🇳 中文',
    'russian': '🇷🇺 Русский',
    'tagalog': '🇵🇭 Tagalog',
  };

  final Map<String, Map<String, String>> _localizedStrings = {
    'english': {
      'title': 'Global Chat',
      'empty': 'No messages yet. Be the first!',
      'hint': 'Type a message...',
      'error': 'Error loading chat.',
    },
    'spanish': {
      'title': 'Chat Global',
      'empty': 'Aún no hay mensajes. ¡Sé el primero!',
      'hint': 'Escribe un mensaje...',
      'error': 'Error al cargar el chat.',
    },
    'chinese': {
      'title': '全球聊天',
      'empty': '还没有消息。成为第一个！',
      'hint': '输入消息...',
      'error': '加载聊天时出错。',
    },
    'russian': {
      'title': 'Глобальный чат',
      'empty': 'Сообщений пока нет. Будь первым!',
      'hint': 'Введите сообщение...',
      'error': 'Ошибка при загрузке чата.',
    },
    'tagalog': {
      'title': 'Global Chat',
      'empty': 'Wala pang mga mensahe. Mauna ka na!',
      'hint': 'Mag-type ng mensahe...',
      'error': 'Error sa pag-load ng chat.',
    },
  };

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _loadInitialRegion();
  }

  Future<void> _loadInitialRegion() async {
    final region = await _chatService.getSelectedRegion();
    if (mounted) {
      setState(() => _selectedRegion = region);
    }
  }

  void _showAuthPrompt(_ChatAuthDialogType type) {
    showGeneralDialog(
      context: context,
      barrierLabel: "ChatAuthDialog",
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: LiquidGlassDialog(
            width: 350,
            height: 600,
            child: type == _ChatAuthDialogType.login
                ? LoginDialog(
                    onRegisterRequested: () {
                      Navigator.pop(context);
                      _showAuthPrompt(_ChatAuthDialogType.register);
                    },
                    onLoginSuccess: () {
                      Navigator.pop(context);
                      if (!mounted) return;
                      showCustomSnackBar(context, 'Login successful!',
                          type: SnackBarType.success);
                      setState(() {}); // Refresh chat state
                    },
                  )
                : RegisterDialog(
                    onLoginRequested: () {
                      Navigator.pop(context);
                      _showAuthPrompt(_ChatAuthDialogType.login);
                    },
                    onRegisterSuccess: () {
                      Navigator.pop(context);
                      if (!mounted) return;
                      showCustomSnackBar(context, 'Registration successful!',
                          type: SnackBarType.success);
                      setState(() {}); // Refresh chat state
                    },
                  ),
          ),
        );
      },
    );
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (FirebaseAuth.instance.currentUser == null) {
      showCustomSnackBar(context, 'Please login to chat!',
          type: SnackBarType.error);
      _showAuthPrompt(_ChatAuthDialogType.login);
      return;
    }

    setState(() => _isSending = true);

    try {
      final success = await _chatService.sendMessage(_selectedRegion, text);
      if (success) {
        _textController.clear();
      } else {
        if (!mounted) return;
        showCustomSnackBar(context, 'Failed to send message.',
            type: SnackBarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('cooldown')) {
        showCustomSnackBar(context, 'Please wait before sending another message.',
            type: SnackBarType.info);
      } else {
        showCustomSnackBar(context, 'Error: $e', type: SnackBarType.error);
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  void _showReportDialog(Map<String, dynamic> data, String messageId) async {
    String timestampStr = DateTime.now().toIso8601String();
    if (data['timestamp'] is Timestamp) {
      timestampStr = (data['timestamp'] as Timestamp).toDate().toIso8601String();
    }

    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierLabel: "ReportDialog",
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.5),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: LiquidGlassDialog(
            width: 350,
            child: ReportDialog(
              messageId: messageId,
              originalMessageText: data['text'] ?? '',
              senderId: data['senderUid'] ?? 'unknown',
              senderDevice: data['senderDevice'] ?? 'unknown',
              messageTimestamp: timestampStr,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 500 ? 400.0 : screenWidth * 0.9;
    final strings = _localizedStrings[_selectedRegion] ?? _localizedStrings['english']!;

    return LiquidGlassDialog(
      width: dialogWidth,
      height: 600,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  strings['title']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedRegion,
                dropdownColor: const Color.fromRGBO(30, 30, 30, 0.9),
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                items: _regions.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRegion = val);
                    _chatService.setSelectedRegion(val);
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          
          // Chat Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChatStream(_selectedRegion),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(strings['error']!, style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white54));
                }

                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(child: Text(strings['empty']!, style: const TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Show latest at the bottom
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final messageId = docs[index].id;
                    final text = data['text'] ?? '';
                    final senderName = data['senderName'] ?? 'Guest';
                    final likes = data['likes'] ?? 0;
                    
                    final isMe = data['senderUid'] == FirebaseAuth.instance.currentUser?.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color.fromRGBO(255, 255, 255, 0.15) : const Color.fromRGBO(0, 0, 0, 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: isMe ? Border.all(color: Colors.white24, width: 1) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName, 
                            style: TextStyle(
                              color: isMe ? Colors.blueAccent : Colors.orangeAccent, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            )
                          ),
                          const SizedBox(height: 4),
                          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Like Button
                              GestureDetector(
                                onTap: () {
                                  if (FirebaseAuth.instance.currentUser == null) {
                                    showCustomSnackBar(context, 'Please login to like messages.', type: SnackBarType.info);
                                  } else {
                                    _chatService.likeMessage(_selectedRegion, messageId);
                                  }
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.thumb_up_alt_outlined, color: Colors.white54, size: 16),
                                    const SizedBox(width: 4),
                                    Text('$likes', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Report Button
                              GestureDetector(
                                onTap: () => _showReportDialog(data, messageId),
                                child: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Input Area
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: strings['hint']!,
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey : Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
