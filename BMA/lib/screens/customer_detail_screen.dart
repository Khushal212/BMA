import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({Key? key, required this.customerId})
      : super(key: key);

  @override
  State<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState
    extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<Invoice> _invoices = [];
  List<Payment> _payments = [];
  double _outstanding = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = context.read<AppDatabase>();
    final customer = await db.getCustomer(widget.customerId);
    final invoices =
        await db.getCustomerInvoices(widget.customerId);
    final payments =
        await db.getCustomerPayments(widget.customerId);
    final outstanding =
        await db.getCustomerOutstanding(widget.customerId);
    if (mounted) {
      setState(() {
        _customer = customer;
        _invoices = invoices;
        _payments = payments;
        _outstanding = outstanding;
        _loading = false;
      });
    }
  }

  Future<void> _recordPayment() async {
    final amtCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String mode = 'CASH';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: const Text('Record Payment'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount (Rs.) *',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Required';
                    if (double.tryParse(v) == null ||
                        double.parse(v) <= 0)
                      return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: mode,
                  decoration: const InputDecoration(
                      labelText: 'Mode',
                      border: OutlineInputBorder()),
                  items: ['CASH', 'UPI', 'BANK']
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => mode = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                      border: OutlineInputBorder()),
                ),
              ],
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
                child: const Text('Record')),
          ],
        );
      }),
    );

    if (result != true) return;

    await context.read<AppDatabase>().recordPayment(
          id: const Uuid().v4(),
          customerId: widget.customerId,
          amount: double.parse(amtCtrl.text.trim()),
          mode: mode,
          reference: refCtrl.text.trim().isEmpty
              ? null
              : refCtrl.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded')));
    }
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_customer == null) {
      return const Scaffold(
          body: Center(child: Text('Customer not found')));
    }

    final c = _customer!;
    final exceeded = _outstanding > c.creditLimit;
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar:
          AppBar(title: Text(c.name), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Outstanding card
            Card(
              color: exceeded
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Outstanding',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey)),
                            Text(
                              'Rs.${_outstanding.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: exceeded
                                      ? Colors.red
                                      : Colors.green.shade700),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            const Text('Credit Limit',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey)),
                            Text(
                              'Rs.${c.creditLimit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (exceeded)
                              Text(
                                'EXCEEDED by Rs.${(_outstanding - c.creditLimit).toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _recordPayment,
                        icon: const Icon(Icons.payment),
                        label:
                            const Text('Record Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('Contact Info',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const Divider(),
                    Row(children: [
                      const Icon(Icons.phone,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(c.phone),
                    ]),
                    if (c.address != null &&
                        c.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.address!)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Invoices
            const Text('Invoices',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            if (_invoices.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No invoices yet',
                      style:
                          TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._invoices.map((inv) => Card(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(inv.invoiceNo,
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.w600)),
                      subtitle: Text(fmt.format(
                          DateTime
                              .fromMillisecondsSinceEpoch(
                                  inv.invoiceDate))),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                              'Rs.${inv.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold)),
                          Text(
                            'Bal: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: inv.balanceAmount >
                                        0
                                    ? Colors.red
                                    : Colors.green),
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 16),

            // Payments
            const Text('Payments',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payments yet',
                      style:
                          TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._payments.map((pay) => Card(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.green.shade100,
                        child: const Icon(
                            Icons.arrow_downward,
                            color: Colors.green,
                            size: 18),
                      ),
                      title: Text(
                          'Rs.${pay.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold)),
                      subtitle: Text(
                          '${pay.mode} • ${fmt.format(DateTime.fromMillisecondsSinceEpoch(pay.paymentDate))}'),
                      trailing: pay.reference != null
                          ? Text(pay.reference!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey))
                          : null,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
