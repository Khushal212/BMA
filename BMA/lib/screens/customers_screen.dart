import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final db = context.read<AppDatabase>();
    final list = await db.getAllCustomers();
    if (mounted) {
      setState(() {
        _customers = list;
        _loading = false;
      });
    }
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _showAddEditDialog({Customer? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');
    final addrCtrl =
        TextEditingController(text: existing?.address ?? '');
    final limitCtrl = TextEditingController(
        text:
            (existing?.creditLimit ?? 10000).toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Name required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Phone required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: limitCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Credit Limit (Rs.)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null
                          ? 'Invalid number'
                          : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (result != true) return;

    final db = context.read<AppDatabase>();
    if (existing == null) {
      await db.createCustomer(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addrCtrl.text.trim().isEmpty
            ? null
            : addrCtrl.text.trim(),
        creditLimit: double.parse(limitCtrl.text.trim()),
      );
    } else {
      await db.updateCustomer(existing.copyWith(
        name: Value(nameCtrl.text.trim()),
        phone: Value(phoneCtrl.text.trim()),
        address: Value(addrCtrl.text.trim().isEmpty
            ? null
            : addrCtrl.text.trim()),
        creditLimit: Value(double.parse(limitCtrl.text.trim())),
      ));
    }
    _loadCustomers();
  }

  Future<void> _deleteCustomer(Customer c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Delete "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await context.read<AppDatabase>().deleteCustomer(c.id);
    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Customers'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search name / phone...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _customers.isEmpty
                              ? 'No customers yet.\nTap + to add one.'
                              : 'No results for "$_query"',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final c = _filtered[idx];
                            return FutureBuilder<double>(
                              future: context
                                  .read<AppDatabase>()
                                  .getCustomerOutstanding(c.id),
                              builder: (ctx, snap) {
                                final outstanding =
                                    snap.data ?? 0;
                                final exceeded =
                                    outstanding > c.creditLimit;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: exceeded
                                        ? Colors.red.shade100
                                        : Colors.green.shade100,
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: exceeded
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(c.name,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600)),
                                  subtitle: Text(c.phone),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs.${outstanding.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            color: exceeded
                                                ? Colors.red
                                                : Colors
                                                    .green.shade700,
                                            fontWeight:
                                                FontWeight.bold),
                                      ),
                                      Text(
                                        'Limit: Rs.${c.creditLimit.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CustomerDetailScreen(
                                                customerId: c.id),
                                      ),
                                    );
                                    _loadCustomers();
                                  },
                                  onLongPress: () =>
                                      _showAddEditDialog(
                                          existing: c),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
