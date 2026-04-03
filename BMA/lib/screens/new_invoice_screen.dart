import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _InvoiceLine {
  String? itemId;
  String itemName = '';
  String unit = '';
  double qty = 1;
  double rate = 0;
  double gstPercent = 0;
  double marginPercent = 0;

  // Controllers so fields update when item selected
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController rateCtrl = TextEditingController(text: '0');
  final TextEditingController gstCtrl = TextEditingController(text: '0');
  final TextEditingController marginCtrl = TextEditingController(text: '0');

  double get lineSubtotal => qty * rate;
  double get marginAmount => lineSubtotal * marginPercent / 100;
  double get afterMargin => lineSubtotal + marginAmount;
  double get lineGstAmount => afterMargin * gstPercent / 100;
  double get lineTotal => afterMargin + lineGstAmount;

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
    gstCtrl.dispose();
    marginCtrl.dispose();
  }
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  String? _selectedCustomerId;
  Customer? _selectedCustomer;
  double _customerOutstanding = 0;

  final List<_InvoiceLine> _lines = [];
  double _discountPercent = 0;
  String _paymentType = 'CREDIT';
  double _paidAmount = 0;
  bool _saving = false;

  List<Customer> _customers = [];
  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    _lines.add(_InvoiceLine());
    _loadData();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = context.read<AppDatabase>();
    final customers = await db.getAllCustomers();
    final items = await db.getAllItems();
    if (mounted) {
      setState(() {
        _customers = customers;
        _items = items;
      });
    }
  }

  Future<void> _onCustomerChanged(String? id) async {
    if (id == null) return;
    final db = context.read<AppDatabase>();
    final customer = await db.getCustomer(id);
    final outstanding = await db.getCustomerOutstanding(id);
    if (mounted) {
      setState(() {
        _selectedCustomerId = id;
        _selectedCustomer = customer;
        _customerOutstanding = outstanding;
      });
    }
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.afterMargin);
  double get _discountAmount => _subtotal * _discountPercent / 100;
  double get _gstAmount => _lines.fold(0.0, (s, l) => s + l.lineGstAmount);
  double get _total => _subtotal - _discountAmount + _gstAmount;
  double get _balanceAmount {
    if (_paymentType == 'CREDIT') return _total;
    return (_total - _paidAmount).clamp(0.0, double.infinity);
  }

  bool get _willExceedLimit =>
      _selectedCustomer != null &&
      (_customerOutstanding + _balanceAmount) > _selectedCustomer!.creditLimit;

  Future<void> _saveInvoice() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer')));
      return;
    }
    final validLines =
        _lines.where((l) => l.itemId != null && l.qty > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one item')));
      return;
    }

    setState(() => _saving = true);
    try {
      final db = context.read<AppDatabase>();
      final invoiceNo = await db.generateInvoiceNo();
      final invoiceId = const Uuid().v4();

      final lineData = validLines
          .map((l) => InvoiceLinesCompanion(
                id: Value(const Uuid().v4()),
                invoiceId: Value(invoiceId),
                itemId: Value(l.itemId!),
                itemNameSnapshot: Value(l.itemName),
                qty: Value(l.qty),
                unit: Value(l.unit),
                rate: Value(l.rate),
                lineSubtotal: Value(l.afterMargin),
                lineGstPercent: Value(l.gstPercent),
                lineGstAmount: Value(l.lineGstAmount),
                lineTotal: Value(l.lineTotal),
                marginPercent: Value(l.marginPercent),
              ))
          .toList();

      await db.createInvoice(
        id: invoiceId,
        invoiceNo: invoiceNo,
        customerId: _selectedCustomerId!,
        invoiceDate: DateTime.now().millisecondsSinceEpoch,
        subtotal: _subtotal,
        discountPercent: _discountPercent,
        discountAmount: _discountAmount,
        gstAmount: _gstAmount,
        total: _total,
        paidAmount: _paymentType == 'CREDIT' ? 0 : _paidAmount,
        balanceAmount: _balanceAmount,
        paymentType: _paymentType,
        lines: lineData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invoice $invoiceNo saved ✓'),
          backgroundColor: Colors.green,
        ));
        // Reset form
        for (final l in _lines) l.dispose();
        setState(() {
          _selectedCustomerId = null;
          _selectedCustomer = null;
          _customerOutstanding = 0;
          _lines.clear();
          _lines.add(_InvoiceLine());
          _discountPercent = 0;
          _paymentType = 'CREDIT';
          _paidAmount = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('New Invoice'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer selector
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Select Customer *',
                border: OutlineInputBorder(),
              ),
              items: _customers
                  .map((c) => DropdownMenuItem(
                      value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: _onCustomerChanged,
            ),

            if (_selectedCustomer != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _willExceedLimit
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _willExceedLimit
                          ? Colors.red.shade300
                          : Colors.green.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Due: Rs.${_customerOutstanding.toStringAsFixed(0)}'),
                    Text('Limit: Rs.${_selectedCustomer!.creditLimit.toStringAsFixed(0)}'),
                    if (_willExceedLimit)
                      const Text('WILL EXCEED!',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text('Items',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),

            // Invoice lines
            ..._lines.asMap().entries.map((entry) {
              final idx = entry.key;
              final line = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: line.itemId,
                          decoration: const InputDecoration(
                              labelText: 'Item',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                          items: _items
                              .map((it) => DropdownMenuItem(
                                  value: it.id,
                                  child: Text(it.name,
                                      overflow:
                                          TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            final it =
                                _items.firstWhere((i) => i.id == v);
                            setState(() {
                              line.itemId = v;
                              line.itemName = it.name;
                              line.unit = it.unit;
                              line.gstPercent = it.gstPercent;
                              // Auto-fill default rate
                              if (it.defaultRate != null) {
                                line.rate = it.defaultRate!;
                                line.rateCtrl.text =
                                    it.defaultRate!.toStringAsFixed(0);
                              }
                              line.gstCtrl.text =
                                  it.gstPercent.toStringAsFixed(0);
                            });
                          },
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.red),
                          onPressed: () =>
                              setState(() => _lines.removeAt(idx)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: line.qtyCtrl,
                          decoration: InputDecoration(
                              labelText:
                                  'Qty (${line.unit.isEmpty ? "unit" : line.unit})',
                              border: const OutlineInputBorder(),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() =>
                              line.qty = double.tryParse(v) ?? 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: line.rateCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Rate (Rs.)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() =>
                              line.rate = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: line.marginCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Margin %',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() =>
                              line.marginPercent =
                                  double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: line.gstCtrl,
                          decoration: const InputDecoration(
                              labelText: 'GST %',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8)),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() =>
                              line.gstPercent =
                                  double.tryParse(v) ?? 0),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6)),
                      child: Column(children: [
                        if (line.marginPercent > 0)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Base: Rs.${line.lineSubtotal.toStringAsFixed(0)}  +  Margin(${line.marginPercent.toStringAsFixed(0)}%): Rs.${line.marginAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
                            ],
                          ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Line Total:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                'Rs.${line.lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 13)),
                          ],
                        ),
                      ]),
                    ),
                  ]),
                ),
              );
            }),

            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _lines.add(_InvoiceLine())),
              icon: const Icon(Icons.add),
              label: const Text('Add Item Line'),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Discount slider
            Row(children: [
              const Text('Discount: '),
              Expanded(
                child: Slider(
                  value: _discountPercent,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  label: '${_discountPercent.toStringAsFixed(0)}%',
                  onChanged: (v) =>
                      setState(() => _discountPercent = v),
                ),
              ),
              Text('${_discountPercent.toStringAsFixed(0)}%'),
            ]),

            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentType,
              decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder()),
              items: ['CASH', 'UPI', 'BANK', 'CREDIT', 'MIXED']
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _paymentType = v!),
            ),

            if (_paymentType != 'CREDIT') ...[
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Paid Amount (Rs.)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(
                    () => _paidAmount = double.tryParse(v) ?? 0),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),

            // Summary card
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _summaryRow(
                      'Subtotal (after margin)', _subtotal),
                  if (_discountAmount > 0)
                    _summaryRow(
                        'Discount (${_discountPercent.toStringAsFixed(0)}%)',
                        -_discountAmount,
                        color: Colors.orange),
                  if (_gstAmount > 0)
                    _summaryRow('GST', _gstAmount),
                  const Divider(),
                  _summaryRow('TOTAL', _total,
                      bold: true, fontSize: 18),
                  if (_paymentType != 'CREDIT' && _paidAmount > 0)
                    _summaryRow('Paid', -_paidAmount,
                        color: Colors.green),
                  _summaryRow('Balance Due', _balanceAmount,
                      bold: true,
                      color: _balanceAmount > 0
                          ? Colors.red
                          : Colors.green),
                ]),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveInvoice,
                icon: const Icon(Icons.save),
                label: const Text('Generate & Save Invoice',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount,
          {bool bold = false,
          Color? color,
          double fontSize = 14}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: bold
                        ? FontWeight.bold
                        : FontWeight.normal)),
            Text(
              'Rs.${amount.abs().toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: color),
            ),
          ],
        ),
      );
}
