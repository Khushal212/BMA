import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/item.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({Key? key}) : super(key: key);

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final rateController = TextEditingController();
    final gstController = TextEditingController(text: '0');
    String _selectedUnit = 'kg';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: ['kg', 'crate', 'bunch', 'box', 'bag']
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: (value) => _selectedUnit = value ?? 'kg',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'Default Rate (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gstController,
                decoration: const InputDecoration(labelText: 'GST %'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item name is required')),
                );
                return;
              }

              final db = context.read<AppDatabase>();
              await db.createItem(
                id: const Uuid().v4(),
                name: nameController.text,
                unit: _selectedUnit,
                defaultRate:
                    rateController.text.isEmpty ? null : double.parse(rateController.text),
                gstPercent: double.parse(gstController.text),
              );

              Navigator.pop(context);
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items (Vegetables)'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search item...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Item>>(
              future: db.getAllItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No items yet'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Item'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!;
                final query = _searchController.text.toLowerCase();
                final filtered = items.where((i) => i.name.toLowerCase().contains(query)).toList();

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text('${item.unit} • GST: ${item.gstPercent}%'),
                        trailing: Text(
                          item.defaultRate != null
                              ? '₹${item.defaultRate!.toStringAsFixed(2)}/${item.unit}'
                              : 'No rate',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onLongPress: () => _showEditDeleteOptions(context, item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDeleteOptions(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditItemDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final db = context.read<AppDatabase>();
                await db.deleteItem(item.id);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item deleted')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditItemDialog(Item item) {
    final nameController = TextEditingController(text: item.name);
    final rateController = TextEditingController(text: item.defaultRate?.toString() ?? '');
    final gstController = TextEditingController(text: item.gstPercent.toString());
    String _selectedUnit = item.unit;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: ['kg', 'crate', 'bunch', 'box', 'bag']
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                    .toList(),
                onChanged: (value) => _selectedUnit = value ?? 'kg',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(labelText: 'Default Rate (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gstController,
                decoration: const InputDecoration(labelText: 'GST %'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = context.read<AppDatabase>();
              final updated = item.copyWith(
                name: nameController.text,
                unit: _selectedUnit,
                defaultRate: rateController.text.isEmpty ? null : double.parse(rateController.text),
                gstPercent: double.parse(gstController.text),
              );
              await db.updateItem(updated);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item updated')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
