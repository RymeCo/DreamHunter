import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/community/chat_service.dart';
import 'package:dreamhunter/models/chat_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatDialog extends StatefulWidget {
  final VoidCallback? onMessageSent;
  const ChatDialog({super.key, this.onMessageSent});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedRegion = 'english';
  Map<String, dynamic>? _announcement;

  final Map<String, String> _regions = {
    'english': '🇺🇸 English',
    'spanish': '🇪🇸 Español',
    'chinese': '🇨🇳 中文',
    'russian': '🇷🇺 Русский',
    'tagalog': '🇵🇭 Tagalog',
  };

  @override
  void initState() {
    super.initState();
    _checkAnnouncement();
  }

  @override
  void dispose() {
    ChatService.instance.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAnnouncement() async {
    final announcement = await ChatService.instance.getDailyAnnouncement();
    if (announcement != null && mounted) {
      setState(() => _announcement = announcement);
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      _textController.clear();
      await ChatService.instance.sendMessage(text, region: _selectedRegion);
      if (widget.onMessageSent != null) widget.onMessageSent!();
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardGlassPage(
      title: 'GLOBAL CHAT',
      footer: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.cyanAccent),
              onPressed: () {
                AudioManager().playClick();
                _sendMessage();
              },
            ),
          ],
        ),
      ],
      child: Column(
        children: [
          _buildRegionSelector(),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: StreamBuilder<List<ChatMessage>>(
                stream: ChatService.instance.getMessages(region: _selectedRegion),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!;
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length + (_announcement != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_announcement != null && index == 0) {
                        return _buildAnnouncementCard();
                      }
                      
                      final messageIndex = _announcement != null ? index - 1 : index;
                      final message = messages[messageIndex];
                      return _MessageBubble(message: message);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'REGION:',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _selectedRegion,
          dropdownColor: Colors.black87,
          underline: const SizedBox(),
          items: _regions.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedRegion = v!),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard() {
    final rules = _announcement!['rules'] as List<dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'DAILY ANNOUNCEMENT',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _announcement!['message'],
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          const Divider(color: Colors.white12, height: 20),
          const Text(
            'RULES:',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          ...rules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $rule',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              )),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _announcement = null),
              child: const Text('DISMISS', style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.senderId == FirebaseAuth.instance.currentUser?.uid;
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe)
                Text(
                  message.senderName,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(color: Colors.white24, fontSize: 9),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Text(
                  'YOU',
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? Colors.cyanAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMe ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white12,
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
