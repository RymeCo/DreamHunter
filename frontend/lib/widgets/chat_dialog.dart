import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/backend_service.dart';
import 'package:dreamhunter/services/chat_service.dart';
import 'package:dreamhunter/services/offline_cache.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/report_dialog.dart';
import 'package:dreamhunter/widgets/game_widgets.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

class ChatDialog extends StatefulWidget {
  final ChatService? chatService;
  final VoidCallback? onMessageSent;
  const ChatDialog({super.key, this.chatService, this.onMessageSent});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  late final ChatService _chatService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedRegion = 'english';
  bool _isChatMaintenance = false;
  bool _isModerator = false;
  bool _modCanHideMessages = false;

  final Map<String, String> _regions = {
    'english': '🇺🇸 English',
    'spanish': '🇪🇸 Español',
    'chinese': '🇨🇳 中文',
    'russian': '🇷🇺 Русский',
    'tagalog': '🇵🇭 Tagalog',
    'mod-only': '🛡️ Staff Channel',
  };

  final Map<String, Map<String, String>> _localizedStrings = {
    'english': {
      'title': 'Global Chat',
      'empty': 'No messages yet. Be the first!',
      'hint': 'Type a message...',
      'error': 'Error loading chat.',
      'maintenance': 'Chat is under maintenance. Please try again later.',
    },
    'spanish': {
      'title': 'Chat Global',
      'empty': 'Aún no hay mensajes. ¡Sé el primero!',
      'hint': 'Escribe un mensaje...',
      'error': 'Error al cargar el chat.',
      'maintenance':
          'El chat está en mantenimiento. Por favor, inténtelo de nuevo más tarde.',
    },
    'chinese': {
      'title': '全球聊天',
      'empty': '还没有消息。成为第一个！',
      'hint': '输入消息...',
      'error': '加载聊天时出错。',
      'maintenance': '聊天正在维护中。请稍后再试。',
    },
    'russian': {
      'title': 'Глобальный чат',
      'empty': 'Сообщений пока нет. Будь первым!',
      'hint': 'Введите сообщение...',
      'error': 'Ошибка при загрузке чата.',
      'maintenance':
          'Чат находится на техническом обслуживании. Пожалуйста, попробуйте позже.',
    },
    'tagalog': {
      'title': 'Global Chat',
      'empty': 'Wala pang mga mensahe. Mauna ka na!',
      'hint': 'Mag-type ng mensahe...',
      'error': 'Error sa pag-load ng chat.',
      'maintenance': 'Kasalukuyang inaayos ang chat. Pakisubukang muli mamaya.',
    },
    'mod-only': {
      'title': 'Staff Channel',
      'empty': 'Secure channel active. Team only.',
      'hint': 'Discuss player behavior...',
      'error': 'Error loading staff chat.',
      'maintenance': 'Staff channel is always active.',
    },
  };

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatService();
    _loadInitialRegion();
    _listenToMaintenance();
    _checkModeratorStatus();
    _listenToModConfig();
  }

  void _listenToMaintenance() {
    _chatService.getSystemConfig().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isChatMaintenance = data['chatMaintenance'] ?? false;
        });
      }
    });
  }

  void _checkModeratorStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _isModerator = doc.data()?['isModerator'] ?? false;
        });
      }
    }
  }

  void _listenToModConfig() {
    FirebaseFirestore.instance
        .collection('metadata')
        .doc('moderation_config')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data() as Map<String, dynamic>;
            setState(() {
              _modCanHideMessages = data['modCanHideMessages'] ?? false;
            });
          }
        });
  }

  Future<void> _loadInitialRegion() async {
    final region = await _chatService.getSelectedRegion();
    if (mounted) {
      setState(() => _selectedRegion = region);
    }
  }

  void _sendMessage() async {
    if (_isChatMaintenance) {
      final strings =
          _localizedStrings[_selectedRegion] ?? _localizedStrings['english']!;
      showCustomSnackBar(
        context,
        strings['maintenance']!,
        type: SnackBarType.info,
      );
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (FirebaseAuth.instance.currentUser == null) {
      showCustomSnackBar(
        context,
        'Please log in to use this feature! Use the top right ☰ menu.',
        type: SnackBarType.info,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // ChatService now uses BackendService.sendMessage which handles the 5s cooldown
      final result = await _chatService.sendMessage(_selectedRegion, text);
      
      if (result != null && result['status'] == 'success') {
        _textController.clear();
        
        // Track chat task and reward XP locally
        await OfflineCache.addTransaction(type: 'CHAT');
        widget.onMessageSent?.call();

        // Handle Automod Feedback (censoring etc)
        if (result['censored'] == true && mounted) {
          final String msg = result['muteMessage'] ?? result['warning'] ?? 'Please watch your language!';
          showCustomSnackBar(context, msg, type: SnackBarType.error);
        }
      } else {
        // Handle Cooldown or Flagging errors from BackendService
        if (mounted) {
          showCustomSnackBar(
            context,
            result['message'] ?? 'Failed to send message.',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', type: SnackBarType.error);
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  void _toggleHideMessage(String messageId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_selectedRegion)
          .collection('messages')
          .doc(messageId)
          .update({'adminDisliked': !currentStatus});

      if (!mounted) return;
      showCustomSnackBar(
        context,
        currentStatus ? 'Message restored' : 'Message hidden',
        type: SnackBarType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(
        context,
        'Error updating message visibility',
        type: SnackBarType.error,
      );
    }
  }

  void _showReportDialog(Map<String, dynamic> data, String messageId) async {
    String timestampStr = DateTime.now().toIso8601String();
    if (data['timestamp'] is Timestamp) {
      timestampStr = (data['timestamp'] as Timestamp)
          .toDate()
          .toIso8601String();
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
            height: 500,
            padding: EdgeInsets.zero,
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
    final strings =
        _localizedStrings[_selectedRegion] ?? _localizedStrings['english']!;

    return LiquidGlassDialog(
      width: dialogWidth,
      height: 600,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          GameDialogHeader(
            title: strings['title']!,
            titleColor: Colors.amberAccent,
          ),
          
          // Region Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.language, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRegion,
                  dropdownColor: const Color.fromRGBO(30, 30, 30, 0.9),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
                  items: _regions.entries
                      .where((e) => e.key != 'mod-only' || _isModerator)
                      .map((e) {
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
          ),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // Chat Stream
          Expanded(
            child: _isChatMaintenance
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.build_circle_outlined,
                          color: Colors.orangeAccent,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            strings['maintenance']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChatStream(_selectedRegion),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            strings['error']!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            strings['empty']!,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Show latest at the bottom
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final messageId = docs[index].id;
                          final text = data['text'] ?? '';
                          final senderName = data['senderName'] ?? 'Guest';
                          final likes = data['likes'] ?? 0;
                          final isAdmin = data['isAdmin'] ?? false;
                          final isSystemWarning =
                              data['isSystemWarning'] ?? false;
                          final adminLiked = data['adminLiked'] ?? false;
                          final adminDisliked = data['adminDisliked'] ?? false;

                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          final isMe = data['senderUid'] == currentUserId;
                          final isGhost = data['isGhost'] == true;

                          if (adminDisliked && !_isModerator) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(0, 0, 0, 0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Message removed by Admin',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }

                          // Determine borders and colors
                          Color bgColor = isAdmin
                              ? const Color.fromRGBO(
                                  106,
                                  13,
                                  173,
                                  0.3,
                                ) // Purple tint for admin
                              : (isMe
                                    ? const Color.fromRGBO(255, 255, 255, 0.15)
                                    : const Color.fromRGBO(0, 0, 0, 0.25));

                          Border? border;
                          if (adminLiked) {
                            border = Border.all(
                              color: Colors.amberAccent,
                              width: 2.0,
                            );
                          } else if (isAdmin) {
                            border = Border.all(
                              color: Colors.amberAccent.withValues(alpha: 0.5),
                              width: 1.5,
                            );
                          } else if (isMe) {
                            border = Border.all(
                              color: Colors.white24,
                              width: 1,
                            );
                          }

                          List<BoxShadow>? boxShadow;
                          if (adminLiked) {
                            boxShadow = [
                              BoxShadow(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ];
                          } else if (isAdmin) {
                            boxShadow = [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ];
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: border,
                              boxShadow: boxShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isSystemWarning ? 'SYSTEM' : senderName,
                                      style: TextStyle(
                                        color: isSystemWarning
                                            ? Colors.redAccent
                                            : (isAdmin
                                                  ? Colors.amberAccent
                                                  : (isMe
                                                        ? Colors.blueAccent
                                                        : Colors.orangeAccent)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isAdmin && !isSystemWarning) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        color: Colors.amberAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'DreamMaster',
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                    if (adminLiked) ...[
                                      const Spacer(),
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amberAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Admin Liked',
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: isSystemWarning
                                        ? Colors.yellowAccent
                                        : Colors.white,
                                    fontSize: 14,
                                    fontStyle: isSystemWarning
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Like Button
                                    GestureDetector(
                                      onTap: () {
                                        if (currentUserId == null) {
                                          showCustomSnackBar(
                                            context,
                                            'Please log in to use this feature!',
                                            type: SnackBarType.info,
                                          );
                                        } else {
                                          _chatService.likeMessage(
                                            _selectedRegion,
                                            messageId,
                                          );
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.thumb_up_alt_outlined,
                                            color: Colors.white54,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$likes',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Hide Button (Moderator/Admin)
                                    if (_isModerator && _modCanHideMessages)
                                      GestureDetector(
                                        onTap: () => _toggleHideMessage(
                                          messageId,
                                          adminDisliked,
                                        ),
                                        child: Icon(
                                          adminDisliked
                                              ? Icons.visibility_outlined
                                              : Icons.thumb_down_alt_outlined,
                                          color: adminDisliked
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
                                          size: 16,
                                        ),
                                      ),
                                    if (_isModerator && _modCanHideMessages)
                                      const SizedBox(width: 16),
                                    // Report Button
                                    if (!isAdmin && !isSystemWarning && !isMe && !isGhost)
                                      GestureDetector(
                                        onTap: () =>
                                            _showReportDialog(data, messageId),
                                        child: const Icon(
                                          Icons.flag_outlined,
                                          color: Colors.redAccent,
                                          size: 16,
                                        ),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isChatMaintenance
                      ? () {
                          final strings =
                              _localizedStrings[_selectedRegion] ??
                              _localizedStrings['english']!;
                          showCustomSnackBar(
                            context,
                            strings['maintenance']!,
                            type: SnackBarType.info,
                          );
                        }
                      : null,
                  child: AbsorbPointer(
                    absorbing: _isChatMaintenance,
                    child: TextField(
                      controller: _textController,
                      enabled: !_isChatMaintenance,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _isChatMaintenance
                            ? 'Chat Disabled'
                            : strings['hint']!,
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.black45,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassButton(
                onTap: _isSending
                    ? null
                    : () {
                        if (_isChatMaintenance) {
                          final strings =
                              _localizedStrings[_selectedRegion] ??
                              _localizedStrings['english']!;
                          showCustomSnackBar(
                            context,
                            strings['maintenance']!,
                            type: SnackBarType.info,
                          );
                        } else {
                          _sendMessage();
                        }
                      },
                padding: const EdgeInsets.all(12),
                borderRadius: 24,
                glowColor: Colors.orangeAccent,
                isClickable: !_isSending && !_isChatMaintenance,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
