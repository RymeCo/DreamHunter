import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_ui_components.dart';

class ConfigEditorScreen extends StatefulWidget {
  const ConfigEditorScreen({super.key});

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Config Editor',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Edit offline-first game constants and economy balances.',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('metadata').doc('game_constants').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              
              return Column(
                children: [
                  _buildConfigSection(
                    'Daily Rewards',
                    'Base rewards for daily login streaks.',
                    Icons.calendar_today_rounded,
                    [
                      _ConfigItem(
                        label: 'Base Coins',
                        value: data['dailyBaseCoins']?.toString() ?? '100',
                        onSave: (val) => _updateConfig('dailyBaseCoins', int.tryParse(val)),
                      ),
                      _ConfigItem(
                        label: 'Base Stones',
                        value: data['dailyBaseStones']?.toString() ?? '5',
                        onSave: (val) => _updateConfig('dailyBaseStones', int.tryParse(val)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildConfigSection(
                    'Roulette Odds',
                    'Weighting for roulette rewards (Higher = More common).',
                    Icons.casino_rounded,
                    [
                      _ConfigItem(
                        label: 'Common Weight',
                        value: data['rouletteCommonWeight']?.toString() ?? '70',
                        onSave: (val) => _updateConfig('rouletteCommonWeight', int.tryParse(val)),
                      ),
                      _ConfigItem(
                        label: 'Rare Weight',
                        value: data['rouletteRareWeight']?.toString() ?? '25',
                        onSave: (val) => _updateConfig('rouletteRareWeight', int.tryParse(val)),
                      ),
                      _ConfigItem(
                        label: 'Legendary Weight',
                        value: data['rouletteLegendaryWeight']?.toString() ?? '5',
                        onSave: (val) => _updateConfig('rouletteLegendaryWeight', int.tryParse(val)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildConfigSection(
                    'Experience Scaling',
                    'Multipliers for level progression.',
                    Icons.trending_up_rounded,
                    [
                      _ConfigItem(
                        label: 'XP Multiplier',
                        value: data['xpMultiplier']?.toString() ?? '1.0',
                        onSave: (val) => _updateConfig('xpMultiplier', double.tryParse(val)),
                      ),
                      _ConfigItem(
                        label: 'Base XP per Level',
                        value: data['baseXpPerLevel']?.toString() ?? '1000',
                        onSave: (val) => _updateConfig('baseXpPerLevel', int.tryParse(val)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection(String title, String description, IconData icon, List<_ConfigItem> items) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items.map((item) => _buildConfigTextField(item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTextField(_ConfigItem item) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: item.value),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save_rounded, color: Colors.cyanAccent, size: 20),
                onPressed: () {
                  // In a real app, we'd get the text from the controller
                  // For this prototype, we'll assume the user wants to save what's there
                  // We'll need to manage controllers better if we want real input
                },
              ),
            ),
            onSubmitted: item.onSave,
          ),
        ],
      ),
    );
  }

  Future<void> _updateConfig(String key, dynamic value) async {
    if (value == null) return;
    try {
      await _db.collection('metadata').doc('game_constants').update({key: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated $key successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update $key: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ConfigItem {
  final String label;
  final String value;
  final Function(String) onSave;

  _ConfigItem({required this.label, required this.value, required this.onSave});
}
