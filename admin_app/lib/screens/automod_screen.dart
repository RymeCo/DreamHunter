import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/admin_ui_components.dart';

class AutoModScreen extends StatefulWidget {
  const AutoModScreen({super.key});

  @override
  State<AutoModScreen> createState() => _AutoModScreenState();
}

class _AutoModScreenState extends State<AutoModScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _wordController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  void _addWord(List<String> currentWords) async {
    final word = _wordController.text.trim().toLowerCase();
    if (word.isEmpty || currentWords.contains(word)) return;

    final updatedWords = List<String>.from(currentWords)..add(word);
    final success = await _adminService.updateAutoModConfig({'bannedWords': updatedWords});
    
    if (mounted) {
      if (success) {
        _wordController.clear();
        showCustomSnackBar(context, 'Word added to blacklist.',
            type: SnackBarType.success);
      } else {
        showCustomSnackBar(context, 'Failed to update config.',
            type: SnackBarType.error);
      }
    }
  }

  void _removeWord(String word, List<String> currentWords) async {
    final updatedWords = List<String>.from(currentWords)..remove(word);
    final success = await _adminService.updateAutoModConfig({'bannedWords': updatedWords});
    if (mounted && success) {
      showCustomSnackBar(context, 'Word removed.', type: SnackBarType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _adminService.getAutoModConfigStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final bannedWords = List<String>.from(data['bannedWords'] ?? []);
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminHeader(title: 'Auto-Moderation Engine'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 900;

                    return Column(
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildPermissionsPanel(data),
                                      const SizedBox(height: 24),
                                      _buildStrikeSettingsPanel(data),
                                    ],
                                  )),
                              const SizedBox(width: 24),
                              Expanded(
                                  flex: 6,
                                  child: _buildBlacklistPanel(bannedWords)),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildPermissionsPanel(data, width: double.infinity),
                              const SizedBox(height: 24),
                              _buildStrikeSettingsPanel(data, width: double.infinity),
                              const SizedBox(height: 24),
                              _buildBlacklistPanel(bannedWords, width: double.infinity),
                            ],
                          ),
                        const SizedBox(height: 48),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStrikeSettingsPanel(Map<String, dynamic> data, {double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Strike System & Decay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildNumberSetting(
            'Decay Period (Days)',
            data['decayDays'] ?? 30,
            (v) => _updateSetting('decayDays', v),
          ),
          const Divider(color: Color(0xFF2A2A4A), height: 32),
          const Text('Automatic Sanctions',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildActionSetting(
            'On 3 strikes:',
            data['strike3Action'] ?? 'mute',
            data['strike3DurationHours'] ?? 24,
            (action) => _updateSetting('strike3Action', action),
            (hours) => _updateSetting('strike3DurationHours', hours),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberSetting(
      String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        Row(
          children: [
            IconButton(
              onPressed: () => onChanged(value - 1),
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            Text('$value',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionSetting(String label, String action, int hours,
      ValueChanged<String> onAction, ValueChanged<int> onHours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<String>(
              value: action,
              dropdownColor: const Color(0xFF1E1E3A),
              items: ['mute', 'ban']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (v) => v != null ? onAction(v) : null,
            ),
            const SizedBox(width: 16),
            const Text('for'),
            const SizedBox(width: 16),
            DropdownButton<int>(
              value: hours,
              dropdownColor: const Color(0xFF1E1E3A),
              items: [1, 6, 12, 24, 48, 72, 168]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e hrs')))
                  .toList(),
              onChanged: (v) => v != null ? onHours(v) : null,
            ),
          ],
        ),
      ],
    );
  }

  void _updateSetting(String field, dynamic value) async {
    final success = await _adminService.updateAutoModConfig({field: value});
    if (mounted && success) {
      showCustomSnackBar(context, 'Auto-Mod settings updated.',
          type: SnackBarType.success);
    }
  }

  Widget _buildPermissionsPanel(Map<String, dynamic> data, {double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moderator Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _modToggle('Allow Muting', data['modCanMute'] ?? true, 'modCanMute'),
          const Divider(color: Color(0xFF2A2A4A), height: 24),
          _modToggle('Allow Warning', data['modCanWarn'] ?? true, 'modCanWarn'),
          const Divider(color: Color(0xFF2A2A4A), height: 24),
          _modToggle('Allow Hiding Messages', data['modCanHideMessages'] ?? true, 'modCanHideMessages'),
          const Divider(color: Color(0xFF2A2A4A), height: 24),
          _modToggle('Allow Role Management', data['modCanManageRoles'] ?? false, 'modCanManageRoles'),
        ],
      ),
    );
  }

  Widget _buildBlacklistPanel(List<String> bannedWords, {double? width}) {
    return AdminCard(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Global Word Blacklist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AdminTextField(
                  controller: _wordController,
                  label: 'Blacklist Word',
                  hint: 'Enter offensive term...',
                  onSubmitted: (_) => _addWord(bannedWords),
                ),
              ),
              const SizedBox(width: 12),
              AdminButton(onPressed: () => _addWord(bannedWords), label: 'ADD'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('CURRENTLY BLOCKED',
              style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            height: 300,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A4A)),
            ),
            child: bannedWords.isEmpty
                ? const Center(child: Text('No words blacklisted.', style: TextStyle(color: Colors.white12)))
                : ListView.builder(
                    itemCount: bannedWords.length,
                    itemBuilder: (context, index) {
                      final word = bannedWords[index];
                      return ListTile(
                        dense: true,
                        title: Text(word, style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                          onPressed: () => _removeWord(word, bannedWords),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _modToggle(String label, bool value, String field) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70))),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: (v) => _updateSetting(field, v),
          activeThumbColor: Colors.amberAccent,
          activeTrackColor: Colors.amberAccent.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}
