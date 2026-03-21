import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/custom_snackbar.dart';

class RouletteManagementScreen extends StatefulWidget {
  const RouletteManagementScreen({super.key});

  @override
  State<RouletteManagementScreen> createState() => _RouletteManagementScreenState();
}

class _RouletteManagementScreenState extends State<RouletteManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _rewardNameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dailyFreeSpinsController = TextEditingController();
  final TextEditingController _maxFreeSpinsController = TextEditingController();
  final TextEditingController _spinBuyPriceController = TextEditingController();
  
  String _selectedRewardType = 'currency'; // 'item' or 'currency'
  String _selectedColor = '0xFFFFD740'; // Default Amber
  String? _selectedItemId;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _db.collection('metadata').doc('roulette_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          _dailyFreeSpinsController.text = (data['dailyFreeSpins'] ?? 1).toString();
          _maxFreeSpinsController.text = (data['maxFreeSpins'] ?? 10).toString();
          _spinBuyPriceController.text = (data['spinBuyPrice'] ?? 50).toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _dailyFreeSpinsController.text = '1';
          _maxFreeSpinsController.text = '10';
          _spinBuyPriceController.text = '50';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Error loading config: $e', type: SnackBarType.error);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    try {
      final dailySpins = int.tryParse(_dailyFreeSpinsController.text) ?? 1;
      final maxSpins = int.tryParse(_maxFreeSpinsController.text) ?? 10;
      final buyPrice = int.tryParse(_spinBuyPriceController.text) ?? 50;

      await _db.collection('metadata').doc('roulette_config').set({
        'rewards': _rewards,
        'dailyFreeSpins': dailySpins,
        'maxFreeSpins': maxSpins,
        'spinBuyPrice': buyPrice,
        'spinBuyCurrency': 'dreamCoins',
      });
      if (!mounted) return;
      showCustomSnackBar(context, 'Roulette config saved!', type: SnackBarType.success);
    } catch (e) {
      showCustomSnackBar(context, 'Error saving config: $e', type: SnackBarType.error);
    }
  }

  void _addReward() {
    final name = _rewardNameController.text.trim();
    final weight = int.tryParse(_weightController.text) ?? 1;
    final amount = int.tryParse(_amountController.text);

    if (name.isEmpty) {
      showCustomSnackBar(context, 'Reward name is required', type: SnackBarType.info);
      return;
    }

    final newReward = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'type': _selectedRewardType,
      'itemId': _selectedRewardType == 'item' ? _selectedItemId : null,
      'amount': _selectedRewardType == 'currency' ? amount : null,
      'weight': weight,
      'color': _selectedColor,
    };

    setState(() {
      _rewards.add(newReward);
      _rewardNameController.clear();
      _weightController.clear();
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isNarrow = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminHeader(
              title: 'Roulette & Daily Rewards',
              actions: [
                AdminButton(
                  onPressed: _saveConfig,
                  label: 'SAVE ALL CHANGES',
                  icon: Icons.save_rounded,
                  color: Colors.greenAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isNarrow)
              Column(
                children: [
                  _buildGlobalSettings(),
                  const SizedBox(height: 24),
                  _buildAddRewardForm(),
                  const SizedBox(height: 24),
                  _buildRewardsList(),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildGlobalSettings(),
                        const SizedBox(height: 24),
                        _buildAddRewardForm(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildRewardsList()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSettings() {
    return AdminCard(
      child: Column(
        children: [
          const Text('GLOBAL RULES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 16),
          AdminTextField(controller: _dailyFreeSpinsController, label: 'Daily Free Spins'),
          const SizedBox(height: 16),
          AdminTextField(controller: _maxFreeSpinsController, label: 'Max Storable Spins'),
          const SizedBox(height: 16),
          AdminTextField(controller: _spinBuyPriceController, label: 'Buy Spin Price (DC)'),
        ],
      ),
    );
  }

  Widget _buildAddRewardForm() {
    return AdminCard(
      child: Column(
        children: [
          const Text('ADD REWARD SEGMENT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 16),
          AdminTextField(controller: _rewardNameController, label: 'Reward Name (e.g. 500 Coins)'),
          const SizedBox(height: 16),
          _buildDropdown('Reward Type', _selectedRewardType, ['currency', 'item'], (val) {
            setState(() => _selectedRewardType = val!);
          }),
          const SizedBox(height: 16),
          if (_selectedRewardType == 'currency')
            AdminTextField(controller: _amountController, label: 'Amount')
          else
            _buildItemDropdown(),
          const SizedBox(height: 16),
          AdminTextField(controller: _weightController, label: 'Probability Weight (e.g. 10)'),
          const SizedBox(height: 16),
          _buildColorPicker(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AdminButton(
              onPressed: _addReward,
              label: 'ADD TO WHEEL',
              icon: Icons.add_circle_outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsList() {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WHEEL SEGMENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 16),
          if (_rewards.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No rewards added yet.'))),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rewards.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final reward = _rewards[index];
              final color = Color(int.parse(reward['color'].replaceFirst('0x', ''), radix: 16));
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(width: 12, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                title: Text(reward['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Type: ${reward['type']} • Weight: ${reward['weight']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() => _rewards.removeAt(index)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('shop_items').snapshots(),
      builder: (context, snapshot) {
        final items = snapshot.data?.docs.map((d) => {'id': d.id, 'name': d['name']}).toList() ?? [];
        return _buildDropdown(
          'Select Item',
          _selectedItemId ?? (items.isNotEmpty ? items.first['id'] : ''),
          items.map((i) => i['id'] as String).toList(),
          (val) => setState(() => _selectedItemId = val),
          displayItems: items.map((i) => i['name'] as String).toList(),
        );
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, {List<String>? displayItems}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A4A)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E3A),
              items: List.generate(items.length, (index) {
                return DropdownMenuItem(
                  value: items[index],
                  child: Text(displayItems != null ? displayItems[index] : items[index]),
                );
              }),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    final colors = {
      'Red': '0xFFFF5252',
      'Green': '0xFF69F0AE',
      'Blue': '0xFF40C4FF',
      'Amber': '0xFFFFD740',
      'Purple': '0xFFE040FB',
      'Orange': '0xFFFFAB40',
      'Cyan': '0xFF18FFFF',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Segment Color', style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: colors.entries.map((e) {
            final isSelected = _selectedColor == e.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = e.value),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(int.parse(e.value.replaceFirst('0x', ''), radix: 16)),
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
