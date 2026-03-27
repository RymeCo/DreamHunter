import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';

class ChatDialog extends StatefulWidget {
  final VoidCallback? onMessageSent;
  const ChatDialog({super.key, this.onMessageSent});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _textController = TextEditingController();
  String _selectedRegion = 'english';

  final Map<String, String> _regions = {
    'english': '🇺🇸 English',
    'spanish': '🇪🇸 Español',
    'chinese': '🇨🇳 中文',
    'russian': '🇷🇺 Русский',
    'tagalog': '🇵🇭 Tagalog',
  };

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    
    // UI-only feedback
    final text = _textController.text.trim();
    _textController.clear();
    
    showCustomSnackBar(
      context,
      'Message sent (Offline mode): $text',
      type: SnackBarType.success,
    );

    if (widget.onMessageSent != null) widget.onMessageSent!();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MapEntry('spaceBetween', null).key == 'spaceBetween' ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                const Text('Global Chat', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedRegion,
                  dropdownColor: Colors.black87,
                  items: _regions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _selectedRegion = v!),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Text('Chat messages will appear here', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Type a message...', hintStyle: TextStyle(color: Colors.white54)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
