import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_gateway.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ApiGateway _api = ApiGateway();
  bool _isLoading = true;
  bool _chatEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await _api.get('/settings');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _chatEnabled = data['chat_enabled'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching settings: $e')),
        );
      }
    }
  }

  Future<void> _toggleChat(bool value) async {
    final originalValue = _chatEnabled;
    setState(() => _chatEnabled = value);

    try {
      final response = await _api.patch(
        '/settings',
        body: {'chat_enabled': value},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      setState(() => _chatEnabled = originalValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating chat status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Control global chat settings for all players.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: SwitchListTile(
              title: const Text('Global Chat Enabled'),
              subtitle: const Text(
                'When disabled, players will be unable to send or receive messages.',
              ),
              value: _chatEnabled,
              onChanged: _toggleChat,
              secondary: Icon(
                _chatEnabled ? Icons.chat : Icons.chat_bubble_outline,
                color: _chatEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
