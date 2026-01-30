import 'package:flutter/material.dart';
import 'package:bma/database/app_database.dart' as db;

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final database = db.AppDatabase();

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: FutureBuilder<db.Customer?>(
        future: database.getCustomer(customerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final customer = snap.data;
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(customer.name ?? 'Unnamed'),
                subtitle: Text(customer.phone ?? ''),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<List<db.Invoice>>(
                  future: database.getCustomerInvoices(customerId),
                  builder: (context, invSnap) {
                    if (invSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (invSnap.hasError) {
                      return Center(child: Text('Error: ${invSnap.error}'));
                    }
                    final invoices = invSnap.data ?? [];
                    if (invoices.isEmpty) {
                      return const Center(child: Text('No invoices'));
                    }
                    return ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final inv = invoices[idx];
                        return ListTile(
                          title: Text('Invoice #${inv.id}'),
                          subtitle: Text('Total: ₹${inv.totalAmount ?? 0}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
