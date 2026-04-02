import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() =>
      _CustomersScreenState();
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
    final list =
        await context.read<AppDatabase>().getAllCustomers();
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

  // ── Validators ─────────────────────────────────────────────
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    if (v.trim().length > 50) return 'Name too long (max 50 chars)';
    final nameRegex = RegExp(r"^[a-zA-Z\u0900-\u097F\u0A80-\u0AFF\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F\s.'-]+$");
    if (!nameRegex.hasMatch(v.trim())) return 'Name contains invalid characters';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Mobile must start with 6, 7, 8, or 9';
    return null;
  }

  String? _validateCreditLimit(String? v) {
    if (v == null || v.trim().isEmpty) return 'Credit limit required';
    final amount = double.tryParse(v.trim());
    if (amount == null) return 'Enter a valid number';
    if (amount < 0) return 'Cannot be negative';
    if (amount > 10000000) return 'Limit too high';
    return null;
  }

  Future<void> _showAddEditDialog({Customer? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');
    final addrCtrl =
        TextEditingController(text: existing?.address ?? '');
    final limitCtrl = TextEditingController(
        text: (existing?.creditLimit ?? 10000)
            .toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            existing == null ? 'Add Customer' : 'Edit Customer'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Ramesh Kumar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization:
                      TextCapitalization.words,
                  validator: _validateName,
                  autovalidateMode:
                      AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '10-digit mobile number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: _validatePhone,
                  autovalidateMode:
                      AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: limitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit (Rs.) *',
                    hintText: 'e.g. 10000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                    prefixText: 'Rs. ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: _validateCreditLimit,
                  autovalidateMode:
                      AutovalidateMode.onUserInteraction,
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
        creditLimit:
            double.parse(limitCtrl.text.trim()),
      );
    } else {
      await db.updateCustomer(existing.copyWith(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addrCtrl.text.trim().isEmpty
            ? null
            : addrCtrl.text.trim(),
        creditLimit:
            double.parse(limitCtrl.text.trim()),
      ));
    }
    _loadCustomers();
  }

  Future<void> _deleteCustomer(Customer c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
            'Delete "${c.name}"? All invoices and payments for this customer will also be affected.'),
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
        title: const Text('Customers'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('${_customers.length}',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
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
              decoration: InputDecoration(
                hintText: 'Search name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) =>
                  setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64,
                                color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _customers.isEmpty
                                  ? 'No customers yet.\nTap + to add one.'
                                  : 'No results for "$_query"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      Colors.grey.shade500),
                            ),
                          ],
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
                                  .getCustomerOutstanding(
                                      c.id),
                              builder: (ctx, snap) {
                                final out = snap.data ?? 0;
                                final exceeded =
                                    out > c.creditLimit;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: exceeded
                                        ? Colors.red.shade100
                                        : Colors
                                            .green.shade100,
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: exceeded
                                              ? Colors.red
                                              : Colors.green
                                                  .shade700,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(c.name,
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w600)),
                                  subtitle: Text('+91 ${c.phone}'),
                                  trailing: Column(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs.${out.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            color: exceeded
                                                ? Colors.red
                                                : Colors.green
                                                    .shade700,
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
                                                customerId:
                                                    c.id),
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
