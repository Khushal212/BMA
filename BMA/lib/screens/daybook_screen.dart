import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class DaybookScreen extends StatefulWidget {
  const DaybookScreen({Key? key}) : super(key: key);
  @override
  State<DaybookScreen> createState() => _DaybookScreenState();
}

class _DaybookEntry {
  final String type; // INVOICE or PAYMENT
  final String title;
  final String subtitle;
  final double amount;
  final bool isCashIn;
  final int timestamp;

  _DaybookEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCashIn,
    required this.timestamp,
  });
}

class _DaybookScreenState extends State<DaybookScreen> {
  DateTime _selectedDate = DateTime.now();
  List<_DaybookEntry> _entries = [];
  bool _loading = false;
  double _cashIn = 0;
  double _cashOut = 0;
  double _creditSales = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final fmt = DateFormat('dd MMM, hh:mm a');

    final start = DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day)
        .millisecondsSinceEpoch;
    final end = DateTime(_selectedDate.year,
            _selectedDate.month, _selectedDate.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    final allInvoices = await db.getAllInvoices();
    final dayInvoices = allInvoices.where((i) =>
        i.invoiceDate >= start && i.invoiceDate <= end);

    final allCustomers = await db.getAllCustomers();
    final allPayments = <Payment>[];
    for (final c in allCustomers) {
      final payments = await db.getCustomerPayments(c.id);
      allPayments.addAll(payments.where((p) =>
          p.paymentDate >= start && p.paymentDate <= end));
    }

    final entries = <_DaybookEntry>[];
    double cashIn = 0, cashOut = 0, creditSales = 0;

    for (final inv in dayInvoices) {
      final customer = allCustomers
          .firstWhere((c) => c.id == inv.customerId,
              orElse: () => allCustomers.first);
      if (inv.paymentType == 'CREDIT') {
        creditSales += inv.total;
        entries.add(_DaybookEntry(
          type: 'INVOICE',
          title: '${customer.name} — ${inv.invoiceNo}',
          subtitle: 'Credit sale • ${DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate))}',
          amount: inv.total,
          isCashIn: false,
          timestamp: inv.invoiceDate,
        ));
      } else {
        cashIn += inv.paidAmount;
        entries.add(_DaybookEntry(
          type: 'INVOICE',
          title: '${customer.name} — ${inv.invoiceNo}',
          subtitle: '${inv.paymentType} • ${DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate))}',
          amount: inv.paidAmount,
          isCashIn: true,
          timestamp: inv.invoiceDate,
        ));
      }
    }

    for (final pay in allPayments) {
      final customer = allCustomers.firstWhere(
          (c) => c.id == pay.customerId,
          orElse: () => allCustomers.first);
      cashIn += pay.amount;
      entries.add(_DaybookEntry(
        type: 'PAYMENT',
        title: '${customer.name} — Payment',
        subtitle: '${pay.mode}${pay.reference != null ? ' • ${pay.reference}' : ''} • ${DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(pay.paymentDate))}',
        amount: pay.amount,
        isCashIn: true,
        timestamp: pay.paymentDate,
      ));
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _entries = entries;
        _cashIn = cashIn;
        _cashOut = cashOut;
        _creditSales = creditSales;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, dd MMM yyyy');
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'Go to today',
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                _load();
              }),
        ],
      ),
      body: Column(children: [
        // Date selector
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _selectedDate =
                      _selectedDate.subtract(
                          const Duration(days: 1)));
                  _load();
                },
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _load();
                  }
                },
                child: Text(
                  isToday ? 'Today' : fmt.format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday
                    ? null
                    : () {
                        setState(() => _selectedDate =
                            _selectedDate.add(
                                const Duration(days: 1)));
                        _load();
                      },
              ),
            ],
          ),
        ),

        // Summary cards
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(child: _SummaryCard(
              'Cash In',
              'Rs.${_cashIn.toStringAsFixed(0)}',
              Colors.green,
              Icons.arrow_downward,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              'Credit Sales',
              'Rs.${_creditSales.toStringAsFixed(0)}',
              Colors.orange,
              Icons.pending,
            )),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(
              'Net Cash',
              'Rs.${(_cashIn - _cashOut).toStringAsFixed(0)}',
              Colors.blue,
              Icons.account_balance,
            )),
          ]),
        ),

        const Divider(height: 16),

        // Entries
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.book_outlined,
                              size: 64,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                              'No transactions on this day',
                              style:
                                  TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final e = _entries[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: e.isCashIn
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                e.type == 'PAYMENT'
                                    ? Icons.payment
                                    : e.isCashIn
                                        ? Icons.receipt
                                        : Icons.pending,
                                color: e.isCashIn
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(e.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            subtitle: Text(e.subtitle,
                                style: const TextStyle(
                                    fontSize: 11)),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs.${e.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: e.isCashIn
                                        ? Colors.green.shade700
                                        : Colors.orange,
                                  ),
                                ),
                                Text(
                                  e.isCashIn
                                      ? 'Cash In'
                                      : 'Credit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: e.isCashIn
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}
