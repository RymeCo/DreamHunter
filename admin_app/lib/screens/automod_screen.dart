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
  
  bool _enabled = false;
  int _strike1Hours = 1;
  int _strike2Hours = 24;
  bool _strike3Ban = true;

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
        _enabled = data['autoModEnabled'] ?? false;
        _strike1Hours = data['strike1MuteHours'] ?? 1;
        _strike2Hours = data['strike2MuteHours'] ?? 24;
        _strike3Ban = data['strike3Ban'] ?? true;
        _isLoading = false;
      });
    });
  }

  void _updateConfig() async {
    final success = await _adminService.updateAutoModConfig({
      'autoModEnabled': _enabled,
      'strike1MuteHours': _strike1Hours,
      'strike2MuteHours': _strike2Hours,
      'strike3Ban': _strike3Ban,
    });
    
    if (mounted) {
      showCustomSnackBar(
        context,
        success ? 'Configuration updated!' : 'Failed to update.',
        type: success ? SnackBarType.success : SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Auto-Moderation Console', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Enable Auto-Moderation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Automatically scans chat for toxic language and applies strikes.'),
                  value: _enabled,
                  onChanged: (val) {
                    setState(() => _enabled = val);
                    _updateConfig();
                  },
                  activeThumbColor: Colors.redAccent,
                ),
                const Divider(height: 40, color: Colors.white24),
                
                const Text('Strike Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                const SizedBox(height: 16),
                
                // Strike 1
                Row(
                  children: [
                    const SizedBox(width: 150, child: Text('Strike 1 (Mute)')),
                    Expanded(
                      child: Slider(
                        value: _strike1Hours.toDouble(),
                        min: 1,
                        max: 24,
                        divisions: 23,
                        label: '$_strike1Hours Hours',
                        onChanged: (val) => setState(() => _strike1Hours = val.toInt()),
                        onChangeEnd: (_) => _updateConfig(),
                      ),
                    ),
                    Text('$_strike1Hours h', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                
                // Strike 2
                Row(
                  children: [
                    const SizedBox(width: 150, child: Text('Strike 2 (Mute)')),
                    Expanded(
                      child: Slider(
                        value: _strike2Hours.toDouble(),
                        min: 1,
                        max: 168, // 1 week
                        divisions: 167,
                        label: '$_strike2Hours Hours',
                        onChanged: (val) => setState(() => _strike2Hours = val.toInt()),
                        onChangeEnd: (_) => _updateConfig(),
                      ),
                    ),
                    Text('$_strike2Hours h', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                
                // Strike 3
                SwitchListTile(
                  title: const Text('Strike 3 (Permanent Ban)'),
                  subtitle: const Text('If off, defaults to a 1-year mute instead.'),
                  value: _strike3Ban,
                  onChanged: (val) {
                    setState(() => _strike3Ban = val);
                    _updateConfig();
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
