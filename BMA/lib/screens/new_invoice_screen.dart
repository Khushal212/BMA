import 'package:flutter/material.dart';
import 'package:bma/database/app_database.dart' as db;
import 'package:bma/utils/invoice_generator.dart' as gen;

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final db.AppDatabase database = db.AppDatabase();

  String? selectedCustomerId;
  final List<_Line> lines = [];

  @override
  void initState() {
    super.initState();
    lines.add(_Line());
  }

  Future<List<db.Customer>> _loadCustomers() => database.getAllCustomers();
  Future<List<db.Item>> _loadItems() => database.getAllItems();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            FutureBuilder<List<db.Customer>>(
              future: _loadCustomers(),
              builder: (context, snap) {
                final customers = snap.data ?? [];
                return DropdownButtonFormField<String>(
                  value: selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Select Customer',
                    border: OutlineInputBorder(),
                  ),
                  items: customers.map<DropdownMenuItem<String>>((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name ?? 'Unnamed'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedCustomerId = v),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<db.Item>>(
                future: _loadItems(),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  return ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, idx) {
                      final line = lines[idx];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: line.itemId,
                                decoration: const InputDecoration(
                                  labelText: 'Item',
                                  border: OutlineInputBorder(),
                                ),
                                items: items.map<DropdownMenuItem<String>>((it) {
                                  return DropdownMenuItem<String>(
                                    value: it.id,
                                    child: Text(it.name ?? 'Unnamed'),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => line.itemId = v),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: line.qty.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => line.qty = double.tryParse(v) ?? 1),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: line.rate.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Rate',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => line.rate = double.tryParse(v) ?? 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => lines.add(_Line())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Line'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Example: create generator lines (uses gen.InvoiceLineData - resolves conflict)
                      final genLines = lines
                          .where((l) => l.itemId != null)
                          .map((l) => gen.InvoiceLineData(
                                itemId: l.itemId!,
                                quantity: l.qty,
                                rate: l.rate,
                              ))
                          .toList();

                      // TODO: call your actual save method here.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lines prepared: ${genLines.length}')),
                      );
                    },
                    child: const Text('Generate / Save'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _Line {
  String? itemId;
  double qty = 1;
  double rate = 0;
}
