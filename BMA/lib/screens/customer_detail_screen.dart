import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/payment.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phone'),
                          Text(
                            widget.customer.phone,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Credit Limit'),
                          Text(
                            '₹${widget.customer.creditLimit.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.customer.address != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.customer.address!)),
                      ],
                    ),
                ],
              ),
            ),

            // Outstanding Balance
            FutureBuilder<double>(
              future: db.getCustomerOutstanding(widget.customer.id),
              builder: (context, snapshot) {
                final outstanding = snapshot.data ?? 0;
                final isExceeded = outstanding > widget.customer.creditLimit;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isExceeded ? Colors.red.shade50 : Colors.blue.shade50,
                    border: Border.all(
                      color: isExceeded ? Colors.red : Colors.blue,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Outstanding Balance'),
                          Text(
                            '₹${outstanding.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isExceeded ? Colors.red : Colors.blue,
                            ),
                          ),
                          if (isExceeded)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'EXCEEDS CREDIT LIMIT!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showRecordPaymentDialog,
                        icon: const Icon(Icons.payment),
                        label: const Text('Record Payment'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Transaction History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Invoice>>(
                    future: db.getCustomerInvoices(widget.customer.id),
                    builder: (context, invoiceSnapshot) {
                      if (!invoiceSnapshot.hasData || invoiceSnapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No invoices')),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: invoiceSnapshot.data!.length,
                        itemBuilder: (context, index) {
                          final invoice = invoiceSnapshot.data![index];
                          final date = DateTime.fromMillisecondsSinceEpoch(invoice.invoiceDate);

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
                                      Text(
                                        invoice.invoiceNo,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(date),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total: ₹${invoice.total.toStringAsFixed(2)}'),
                                      Text(
                                        'Balance: ₹${invoice.balanceAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: invoice.balanceAmount > 0 ? Colors.orange : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog() {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    String _selectedMode = 'CASH';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: ['CASH', 'UPI', 'BANK']
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        ))
                    .toList(),
                onChanged: (value) => _selectedMode = value ?? 'CASH',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                  hintText: 'UPI txn ID, cheque no, etc.',
                ),
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
              if (amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter amount')),
                );
                return;
              }

              final db = context.read<AppDatabase>();
              await db.recordPayment(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                customerId: widget.customer.id,
                amount: double.parse(amountController.text),
                mode: _selectedMode,
                reference: referenceController.text.isEmpty ? null : referenceController.text,
              );

              Navigator.pop(context);
              setState(() {});

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment recorded')),
              );
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }
}
