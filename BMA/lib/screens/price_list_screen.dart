import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({Key? key}) : super(key: key);
  @override
  State<PriceListScreen> createState() =>
      _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  List<Customer> _customers = [];
  List<Item> _items = [];
  Customer? _selectedCustomer;
  bool _loading = true;
  // key = 'price_CUSTOMERID_ITEMID', value = price
  Map<String, double> _prices = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppDatabase>();
    final customers = await db.getAllCustomers();
    final items = await db.getAllItems();
    if (mounted) {
      setState(() {
        _customers = customers;
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _loadPricesForCustomer(String customerId) async {
    final db = context.read<AppDatabase>();
    final prices = <String, double>{};
    for (final item in _items) {
      final key = 'price_${customerId}_${item.id}';
      final saved = await db.getSetting(key);
      if (saved != null) prices[key] = double.parse(saved);
    }
    if (mounted) setState(() => _prices = prices);
  }

  Future<void> _savePrice(
      String customerId, String itemId, double price) async {
    final key = 'price_${customerId}_$itemId';
    await context
        .read<AppDatabase>()
        .saveSetting(key, price.toString());
    setState(() => _prices[key] = price);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price saved ✓'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearPrice(
      String customerId, String itemId) async {
    final key = 'price_${customerId}_$itemId';
    await context
        .read<AppDatabase>()
        .saveSetting(key, '');
    setState(() => _prices.remove(key));
  }

  Future<void> _showEditDialog(Item item) async {
    if (_selectedCustomer == null) return;
    final key =
        'price_${_selectedCustomer!.id}_${item.id}';
    final currentPrice = _prices[key];
    final ctrl = TextEditingController(
        text: currentPrice?.toStringAsFixed(2) ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom Price — ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${_selectedCustomer!.name}',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13),
            ),
            Text(
              'Default price: Rs.${item.defaultRate?.toStringAsFixed(2) ?? "Not set"}',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText:
                    'Custom Rate per ${item.unit}',
                border: const OutlineInputBorder(),
                prefixText: 'Rs. ',
                helperText:
                    'Leave empty to use default price',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(
                      decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
        ),
        actions: [
          if (currentPrice != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _clearPrice(
                    _selectedCustomer!.id, item.id);
              },
              child: const Text('Clear',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final price =
                  double.tryParse(ctrl.text.trim());
              if (price != null && price > 0) {
                _savePrice(
                    _selectedCustomer!.id, item.id, price);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Lists'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Info banner
              Container(
                width: double.infinity,
                color: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Set special rates per customer. '
                      'These override default prices on invoices.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),

              // Customer dropdown
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  value: _selectedCustomer?.id,
                  decoration: const InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _customers
                      .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name)))
                      .toList(),
                  onChanged: (v) async {
                    final c = _customers
                        .firstWhere((c) => c.id == v);
                    setState(() => _selectedCustomer = c);
                    await _loadPricesForCustomer(v!);
                  },
                ),
              ),

              if (_selectedCustomer == null)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.price_change,
                            size: 64,
                            color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Select a customer to set\ncustom prices for them',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final key =
                          'price_${_selectedCustomer!.id}_${item.id}';
                      final customPrice = _prices[key];
                      final hasCustom = customPrice != null;
                      final defaultPrice =
                          item.defaultRate;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasCustom
                              ? Colors.purple.shade100
                              : Colors.grey.shade100,
                          child: Text(
                            item.name[0].toUpperCase(),
                            style: TextStyle(
                              color: hasCustom
                                  ? Colors.purple
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600)),
                        subtitle: Text(
                          defaultPrice != null
                              ? 'Default: Rs.${defaultPrice.toStringAsFixed(0)}/${item.unit}'
                              : 'No default price',
                          style: const TextStyle(
                              fontSize: 12),
                        ),
                        trailing: hasCustom
                            ? Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Rs.${customPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Text('custom rate',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              Colors.grey)),
                                ],
                              )
                            : const Text('default',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey)),
                        onTap: () => _showEditDialog(item),
                      );
                    },
                  ),
                ),
            ]),
    );
  }
}

// Helper function used in new_invoice_screen.dart
// to get customer-specific price for an item
Future<double?> getCustomerItemPrice(
    AppDatabase db, String customerId, String itemId) async {
  final key = 'price_${customerId}_$itemId';
  final saved = await db.getSetting(key);
  if (saved != null && saved.isNotEmpty) {
    return double.tryParse(saved);
  }
  return null;
}
