import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_ui_components.dart';
import '../widgets/custom_snackbar.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedType = 'item';
  String _selectedCurrency = 'coins';

  void _addShopItem() async {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim());
    final desc = _descController.text.trim();

    if (name.isEmpty || price == null) {
      showCustomSnackBar(context, 'Name and Price are required.', type: SnackBarType.info);
      return;
    }

    try {
      await _db.collection('shop_items').add({
        'name': name,
        'type': _selectedType,
        'price': price,
        'currencyType': _selectedCurrency,
        'description': desc,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showCustomSnackBar(context, 'Item added to shop!', type: SnackBarType.success);
      _nameController.clear();
      _priceController.clear();
      _descController.clear();
    } catch (e) {
      showCustomSnackBar(context, 'Error adding item: $e', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminHeader(title: 'Shop Catalog Management'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form to add items
              Expanded(
                flex: 1,
                child: AdminCard(
                  child: Column(
                    children: [
                      const Text('ADD NEW ITEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      const SizedBox(height: 16),
                      AdminTextField(controller: _nameController, label: 'Item Name'),
                      const SizedBox(height: 16),
                      AdminTextField(
                        controller: _priceController, 
                        label: 'Price',
                      ),
                      const SizedBox(height: 16),
                      _buildDropdown('Category', _selectedType, ['character', 'powerup', 'item'], (val) {
                        setState(() => _selectedType = val!);
                      }),
                      const SizedBox(height: 16),
                      _buildDropdown('Currency', _selectedCurrency, ['coins', 'tokens'], (val) {
                        setState(() => _selectedCurrency = val!);
                      }),
                      const SizedBox(height: 16),
                      AdminTextField(controller: _descController, label: 'Description', maxLines: 2),
                      const SizedBox(height: 24),
                      AdminButton(onPressed: _addShopItem, label: 'PUBLISH TO SHOP', icon: Icons.publish_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // List of current items
              Expanded(
                flex: 2,
                child: AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CURRENT CATALOG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('shop_items').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final items = snapshot.data!.docs;
                          if (items.isEmpty) return const Center(child: Text('Catalog is empty.'));

                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final item = items[index].data() as Map<String, dynamic>;
                              final id = items[index].id;
                              return ListTile(
                                title: Text(item['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${item['type']} • ${item['price']} ${item['currencyType']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _db.collection('shop_items').doc(id).delete(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
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
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E3A),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
