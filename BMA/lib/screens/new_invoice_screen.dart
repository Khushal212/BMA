import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/customer.dart';
import '../models/item.dart';
import '../utils/invoice_generator.dart';

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  String? _selectedCustomerId;
  final List<_InvoiceLineItem> _lines = [];
  double _discountPercent = 0;
  String _paymentType = 'CASH';
  double _paidAmount = 0;
  double _gstOverride = -1; // -1 means use default

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Invoice'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Customer Selection
            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<Customer>>(
                future: db.getAllCustomers(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final customers = snapshot.data!;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Customer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedCustomerId != null)
                            FutureBuilder<Customer?>(
                              future: db.getCustomer(_selectedCustomerId!),
                              builder: (context, customerSnapshot) {
                                if (!customerSnapshot.hasData) return const SizedBox.shrink();

                                final customer = customerSnapshot.data!;
                                return FutureBuilder<double>(
                                  future: db.getCustomerOutstanding(customer.id),
                                  builder: (context, outstandingSnapshot) {
                                    final outstanding = outstandingSnapshot.data ?? 0;
                                    final willExceed =
                                        (outstanding + _calculateTotal()) > customer.creditLimit;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: willExceed ? Colors.red.shade50 : Colors.blue.shade50,
                                        border: Border.all(
                                          color:
                                              willExceed ? Colors.red.shade300 : Colors.blue.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    customer.phone,
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              ElevatedButton(
                                                onPressed: () => setState(() => _selectedCustomerId = null),
                                                child: const Text('Change'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Outstanding',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    '₹${outstanding.toStringAsFixed(2)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Credit Limit',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    '₹${customer.creditLimit.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (willExceed)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.warning, color: Colors.red, size: 16),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'This invoice will exceed credit limit!',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: null,
                              hint: const Text('Choose customer...'),
                              items: customers
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedCustomerId = value),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_selectedCustomerId != null) ...[
              // Items Selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_lines.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No items added')),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                          final line = _lines[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.itemName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              '${line.qty} ${line.unit}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => setState(() => _lines.removeAt(index)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Rate: ₹${line.rate.toStringAsFixed(2)}/${line.unit}'),
                                      Text(
                                        'Total: ₹${line.getTotal().toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Discount & Payment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Discount %',
                                prefixIcon: Icon(Icons.discount),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  setState(() => _discountPercent = double.tryParse(value) ?? 0),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'GST % (optional, override default)',
                                prefixIcon: Icon(Icons.percent),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  setState(() => _gstOverride = double.tryParse(value) ?? -1),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _paymentType,
                              decoration: const InputDecoration(labelText: 'Payment Type'),
                              items: ['CASH', 'UPI', 'BANK', 'CREDIT', 'MIXED']
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _paymentType = value ?? 'CASH'),
                            ),
                            if (_paymentType != 'CREDIT')
                              Column(
                                children: [
                                  const SizedBox(height: 12),
                                  TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Paid Amount',
                                      prefixText: '₹ ',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) =>
                                        setState(() => _paidAmount = double.tryParse(value) ?? 0),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildInvoiceSummary(),
              ),
              const SizedBox(height: 24),

              // Generate Invoice Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _lines.isEmpty ? null : _generateInvoice,
                    icon: const Icon(Icons.receipt),
                    label: const Text('Generate Invoice'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    final subtotal = _lines.fold(0.0, (sum, line) => sum + (line.qty * line.rate));
    final discountAmount = (subtotal * _discountPercent) / 100;
    final afterDiscount = subtotal - discountAmount;
    final gstPercent = _gstOverride > 0 ? _gstOverride : 18; // Default 18% if not set
    final gstAmount = (afterDiscount * gstPercent) / 100;
    final total = afterDiscount + gstAmount;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('₹${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            if (_discountPercent > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discount ($_discountPercent%)'),
                  Text('-₹${discountAmount.toStringAsFixed(2)}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GST ($gstPercent%)'),
                Text('₹${gstAmount.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final db = context.read<AppDatabase>();

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Item>>(
        future: db.getAllItems(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: CircularProgressIndicator(),
            );
          }

          final items = snapshot.data!;

          return AlertDialog(
            title: const Text('Add Item to Invoice'),
            content: items.isEmpty
                ? const Text('No items available. Add items first.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items
                          .map((item) => ListTile(
                                title: Text(item.name),
                                subtitle: Text('${item.unit} • ₹${item.defaultRate ?? 'N/A'}'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showAddLineDialog(item);
                                },
                              ))
                          .toList(),
                    ),
                  ),
          );
        },
      ),
    );
  }

  void _showAddLineDialog(Item item) {
    final qtyController = TextEditingController();
    final rateController = TextEditingController(text: item.defaultRate?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              decoration: InputDecoration(
                labelText: 'Quantity (${item.unit})',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(
                labelText: 'Rate per unit (₹)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (qtyController.text.isEmpty || rateController.text.isEmpty) {
                return;
              }

              final qty = double.parse(qtyController.text);
              final rate = double.parse(rateController.text);

              setState(() {
                _lines.add(_InvoiceLineItem(
                  itemId: item.id,
                  itemName: item.name,
                  qty: qty,
                  unit: item.unit,
                  rate: rate,
                  gstPercent: item.gstPercent,
                ));
              });

              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  double _calculateTotal() {
    final subtotal = _lines.fold(0.0, (sum, line) => sum + (line.qty * line.rate));
    final discountAmount = (subtotal * _discountPercent) / 100;
    final afterDiscount = subtotal - discountAmount;
    final gstPercent = _gstOverride > 0 ? _gstOverride : 18;
    final gstAmount = (afterDiscount * gstPercent) / 100;
    return afterDiscount + gstAmount;
  }

  Future<void> _generateInvoice() async {
    final db = context.read<AppDatabase>();

    try {
      final invoiceId = const Uuid().v4();
      final now = DateTime.now();
      final invoiceNo = 'INV-${DateFormat('yyyyMM').format(now)}-${now.millisecondsSinceEpoch % 10000}';

      final subtotal = _lines.fold(0.0, (sum, line) => sum + (line.qty * line.rate));
      final discountAmount = (subtotal * _discountPercent) / 100;
      final afterDiscount = subtotal - discountAmount;
      final gstPercent = _gstOverride > 0 ? _gstOverride : 18;
      final gstAmount = (afterDiscount * gstPercent) / 100;
      final total = afterDiscount + gstAmount;

      final balanceAmount = _paymentType == 'CREDIT' ? total : max(0, total - _paidAmount);

      // Create invoice lines
      final invoiceLines = _lines
          .map((line) {
            final lineSubtotal = line.qty * line.rate;
            return InvoiceLineData(
              id: const Uuid().v4(),
              itemId: line.itemId,
              itemName: line.itemName,
              qty: line.qty,
              unit: line.unit,
              rate: line.rate,
              lineSubtotal: lineSubtotal,
              lineGstPercent: line.gstPercent,
              lineGstAmount: (lineSubtotal * line.gstPercent) / 100,
              lineTotal: lineSubtotal + ((lineSubtotal * line.gstPercent) / 100),
            );
          })
          .toList();

      // Save invoice
      await db.createInvoice(
        id: invoiceId,
        invoiceNo: invoiceNo,
        customerId: _selectedCustomerId!,
        lines: invoiceLines,
        subtotal: subtotal,
        discountPercent: _discountPercent,
        discountAmount: discountAmount,
        gstAmount: gstAmount,
        total: total,
        paidAmount: _paymentType == 'CREDIT' ? 0 : _paidAmount,
        balanceAmount: balanceAmount,
        paymentType: _paymentType,
      );

      // Reset form
      setState(() {
        _selectedCustomerId = null;
        _lines.clear();
        _discountPercent = 0;
        _paymentType = 'CASH';
        _paidAmount = 0;
        _gstOverride = -1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice $invoiceNo generated!')),
      );

      // Show preview dialog
      _showInvoicePreview(invoiceId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showInvoicePreview(String invoiceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Generated'),
        content: const Text('Invoice has been saved successfully!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineItem {
  final String itemId;
  final String itemName;
  final double qty;
  final String unit;
  final double rate;
  final double gstPercent;

  _InvoiceLineItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.rate,
    required this.gstPercent,
  });

  double getTotal() {
    final subtotal = qty * rate;
    final gst = (subtotal * gstPercent) / 100;
    return subtotal + gst;
  }
}

double max(double a, double b) => a > b ? a : b;
