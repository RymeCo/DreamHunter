import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';

class AutoModScreen extends StatefulWidget {
  const AutoModScreen({super.key});

  @override
  State<AutoModScreen> createState() => _AutoModScreenState();
}

class _AutoModScreenState extends State<AutoModScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;

  String _moderationLevel = 'none';
  int _decayDays = 30;

  String _strike1Action = 'mute';
  int _strike1DurationHours = 1;

  String _strike2Action = 'mute';
  int _strike2DurationHours = 24;

  String _strike3Action = 'ban';
  int _strike3DurationHours = 8760;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    _adminService.getAutoModConfigStream().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        final legacyEnabled = data['autoModEnabled'] ?? false;
        _moderationLevel = data['moderationLevel'] ?? (legacyEnabled ? 'mild' : 'none');
        _decayDays = data['decayDays'] ?? 30;

        _strike1Action = data['strike1Action'] ?? 'mute';
        _strike1DurationHours = data['strike1DurationHours'] ?? data['strike1MuteHours'] ?? 1;

        _strike2Action = data['strike2Action'] ?? 'mute';
        _strike2DurationHours = data['strike2DurationHours'] ?? data['strike2MuteHours'] ?? 24;

        _strike3Action = data['strike3Action'] ?? (data['strike3Ban'] == true ? 'ban' : 'mute');
        _strike3DurationHours = data['strike3DurationHours'] ?? 8760;

        _isLoading = false;
      });
    });
  }

  void _updateConfig() async {
    final success = await _adminService.updateAutoModConfig({
      'moderationLevel': _moderationLevel,
      'decayDays': _decayDays,
      'strike1Action': _strike1Action,
      'strike1DurationHours': _strike1DurationHours,
      'strike2Action': _strike2Action,
      'strike2DurationHours': _strike2DurationHours,
      'strike3Action': _strike3Action,
      'strike3DurationHours': _strike3DurationHours,
      'autoModEnabled': _moderationLevel != 'none', // For backwards compatibility
    });

    if (mounted) {
      showCustomSnackBar(
        context,
        success ? 'Configuration updated!' : 'Failed to update.',
        type: success ? SnackBarType.success : SnackBarType.error,
      );
    }
  }

  Widget _buildStrikeConfig(
    int strikeNum,
    String action,
    int duration,
    Function(String) onActionChanged,
    Function(int) onDurationChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 150, child: Text('Strike $strikeNum Action', style: const TextStyle(fontWeight: FontWeight.bold))),
            DropdownButton<String>(
              value: action,
              dropdownColor: const Color(0xFF16162F),
              items: const [
                DropdownMenuItem(value: 'mute', child: Text('Chat Mute')),
                DropdownMenuItem(value: 'ban', child: Text('Global Chat Ban')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => onActionChanged(val));
                  _updateConfig();
                }
              },
            ),
          ],
        ),
        if (action == 'mute')
          Row(
            children: [
              const SizedBox(width: 150, child: Text('Mute Duration (h)')),
              Expanded(
                child: Slider(
                  value: duration.toDouble(),
                  min: 1,
                  max: 720, // max 30 days
                  label: '$duration Hours',
                  onChanged: (val) {
                    setState(() => onDurationChanged(val.toInt()));
                  },
                  onChangeEnd: (_) => _updateConfig(),
                ),
              ),
              Text(
                '$duration h',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto-Moderation Console',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moderation Level',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 8),
                const Text(
                  'None: Messages are not filtered.\nMild: Severe toxicity is filtered and struck.\nAggressive: Mild toxicity receives 5-min timeout.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'none', label: Text('None')),
                    ButtonSegment(value: 'mild', label: Text('Mild')),
                    ButtonSegment(value: 'aggressive', label: Text('Aggressive')),
                  ],
                  selected: {_moderationLevel},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _moderationLevel = newSelection.first);
                    _updateConfig();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.redAccent.withValues(alpha: 0.3);
                        }
                        return Colors.transparent;
                      },
                    ),
                  ),
                ),

                const Divider(height: 40, color: Colors.white24),

                const Text(
                  'Strike Configuration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 16),

                _buildStrikeConfig(
                  1,
                  _strike1Action,
                  _strike1DurationHours,
                  (val) => _strike1Action = val,
                  (val) => _strike1DurationHours = val,
                ),
                _buildStrikeConfig(
                  2,
                  _strike2Action,
                  _strike2DurationHours,
                  (val) => _strike2Action = val,
                  (val) => _strike2DurationHours = val,
                ),
                _buildStrikeConfig(
                  3,
                  _strike3Action,
                  _strike3DurationHours,
                  (val) => _strike3Action = val,
                  (val) => _strike3DurationHours = val,
                ),

                const Divider(height: 40, color: Colors.white24),

                const Text(
                  'Strike Decay',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Days of good behavior required to reduce a player\'s strike count by 1.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 150, child: Text('Decay Time (Days)')),
                    Expanded(
                      child: Slider(
                        value: _decayDays.toDouble(),
                        min: 1,
                        max: 365,
                        label: '$_decayDays Days',
                        onChanged: (val) {
                          setState(() => _decayDays = val.toInt());
                        },
                        onChangeEnd: (_) => _updateConfig(),
                      ),
                    ),
                    Text(
                      '$_decayDays d',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
