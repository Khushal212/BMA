import 'package:flutter/material.dart';
import 'package:bma/database/app_database.dart' as db;

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  final db.AppDatabase database = db.AppDatabase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<db.Item> _filter(List<db.Item> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((i) {
      final name = (i.name ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search item name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<db.Item>>(
              future: database.getAllItems(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final List<db.Item> items = snap.data ?? [];
                final filtered = _filter(items);

                if (filtered.isEmpty) {
                  return const Center(child: Text('No items found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return ListTile(
                      title: Text(item.name ?? 'Unnamed item'),
                      subtitle: Text(
                        '${item.unit ?? ''} • ₹${item.defaultRate ?? 'N/A'}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
