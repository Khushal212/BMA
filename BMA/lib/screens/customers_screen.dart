import 'package:flutter/material.dart';
import 'package:bma/database/app_database.dart' as db;

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  // NOTE: If you already provide db from elsewhere (Provider/GetIt), replace this line.
  final db.AppDatabase database = db.AppDatabase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<db.Customer> _filter(List<db.Customer> customers) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return customers;

    return customers.where((c) {
      final name = (c.name ?? '').toLowerCase();
      final phone = (c.phone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search customer name / phone',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<db.Customer>>(
              future: database.getAllCustomers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final List<db.Customer> customers = snap.data ?? [];
                final filtered = _filter(customers);

                if (filtered.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final c = filtered[idx];
                    return ListTile(
                      title: Text(c.name ?? 'Unnamed'),
                      subtitle: Text(c.phone ?? ''),
                      onTap: () {
                        // If you have customer detail screen route, use it.
                        // Navigator.push(...)
                      },
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
