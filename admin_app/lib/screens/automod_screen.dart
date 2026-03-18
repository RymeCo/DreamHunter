import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Local state for changes before saving
  String? _localModerationLevel;
  int? _localDecayDays;
  String? _localStrike1Action;
  int? _localStrike1DurationHours;
  String? _localStrike2Action;
  int? _localStrike2DurationHours;
  String? _localStrike3Action;
  int? _localStrike3DurationHours;

  void _updateConfig(Map<String, dynamic> currentData) async {
    // Combine local state with current data from DB
    final Map<String, dynamic> configToUpdate = {
      'moderationLevel': _localModerationLevel ?? currentData['moderationLevel'] ?? 'none',
      'decayDays': _localDecayDays ?? currentData['decayDays'] ?? 30,
      'strike1Action': _localStrike1Action ?? currentData['strike1Action'] ?? 'mute',
      'strike1DurationHours': _localStrike1DurationHours ?? currentData['strike1DurationHours'] ?? dataOrLegacy(currentData, 'strike1MuteHours', 1),
      'strike2Action': _localStrike2Action ?? currentData['strike2Action'] ?? 'mute',
      'strike2DurationHours': _localStrike2DurationHours ?? currentData['strike2DurationHours'] ?? dataOrLegacy(currentData, 'strike2MuteHours', 24),
      'strike3Action': _localStrike3Action ?? currentData['strike3Action'] ?? (currentData['strike3Ban'] == true ? 'ban' : 'mute'),
      'strike3DurationHours': _localStrike3DurationHours ?? currentData['strike3DurationHours'] ?? 8760,
    };
    
    configToUpdate['autoModEnabled'] = configToUpdate['moderationLevel'] != 'none';

    final success = await _adminService.updateAutoModConfig(configToUpdate);

    if (mounted) {
      showCustomSnackBar(
        context,
        success ? 'Configuration updated!' : 'Failed to update.',
        type: success ? SnackBarType.success : SnackBarType.error,
      );
      // Clear local state after successful update to let Stream take over
      if (success) {
        setState(() {
          _localModerationLevel = null;
          _localDecayDays = null;
          _localStrike1Action = null;
          _localStrike1DurationHours = null;
          _localStrike2Action = null;
          _localStrike2DurationHours = null;
          _localStrike3Action = null;
          _localStrike3DurationHours = null;
        });
      }
    }
  }

  int dataOrLegacy(Map<String, dynamic> data, String legacyKey, int defaultValue) {
    return data[legacyKey] ?? defaultValue;
  }

  Widget _buildStrikeConfig(
    int strikeNum,
    String action,
    int duration,
    Map<String, dynamic> currentData,
    Function(String) onActionChanged,
    Function(int) onDurationChanged, {
    double max = 720, // Default to 30 days
  }) {
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
                  onActionChanged(val);
                  _updateConfig(currentData);
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
                  value: duration.toDouble().clamp(1.0, max),
                  min: 1,
                  max: max,
                  label: '$duration Hours',
                  onChanged: (val) {
                    onDurationChanged(val.toInt());
                  },
                  onChangeEnd: (_) => _updateConfig(currentData),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _adminService.getAutoModConfigStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final legacyEnabled = data['autoModEnabled'] ?? false;

        // Effective values (local state overrides DB data)
        final moderationLevel = _localModerationLevel ?? data['moderationLevel'] ?? (legacyEnabled ? 'mild' : 'none');
        final decayDays = _localDecayDays ?? data['decayDays'] ?? 30;

        final strike1Action = _localStrike1Action ?? data['strike1Action'] ?? 'mute';
        final strike1Duration = _localStrike1DurationHours ?? data['strike1DurationHours'] ?? data['strike1MuteHours'] ?? 1;

        final strike2Action = _localStrike2Action ?? data['strike2Action'] ?? 'mute';
        final strike2Duration = _localStrike2DurationHours ?? data['strike2DurationHours'] ?? data['strike2MuteHours'] ?? 24;

        final strike3Action = _localStrike3Action ?? data['strike3Action'] ?? (data['strike3Ban'] == true ? 'ban' : 'mute');
        final strike3Duration = _localStrike3DurationHours ?? data['strike3DurationHours'] ?? 8760;

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
                      selected: {moderationLevel},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => _localModerationLevel = newSelection.first);
                        _updateConfig(data);
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
                      strike1Action,
                      strike1Duration,
                      data,
                      (val) => setState(() => _localStrike1Action = val),
                      (val) => setState(() => _localStrike1DurationHours = val),
                    ),
                    _buildStrikeConfig(
                      2,
                      strike2Action,
                      strike2Duration,
                      data,
                      (val) => setState(() => _localStrike2Action = val),
                      (val) => setState(() => _localStrike2DurationHours = val),
                    ),
                    _buildStrikeConfig(
                      3,
                      strike3Action,
                      strike3Duration,
                      data,
                      (val) => setState(() => _localStrike3Action = val),
                      (val) => setState(() => _localStrike3DurationHours = val),
                      max: 8760, // Allow up to 1 year for Strike 3
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
                            value: decayDays.toDouble(),
                            min: 1,
                            max: 365,
                            label: '$decayDays Days',
                            onChanged: (val) {
                              setState(() => _localDecayDays = val.toInt());
                            },
                            onChangeEnd: (_) => _updateConfig(data),
                          ),
                        ),
                        Text(
                          '$decayDays d',
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
      },
    );
  }
}
