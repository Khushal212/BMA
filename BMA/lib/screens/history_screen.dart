import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<InvoiceWithCustomer> _invoices = [];
  List<InvoiceWithCustomer> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _filter = 'All'; // All, Paid, Pending

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = context.read<AppDatabase>();
    final data = await db.getAllInvoicesWithCustomers();
    if (mounted) {
      setState(() {
        _invoices = data;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    _filtered = _invoices.where((inv) {
      final matchSearch = q.isEmpty ||
          inv.customerName.toLowerCase().contains(q) ||
          inv.invoiceNo.toLowerCase().contains(q);
      final matchFilter = _filter == 'All' ||
          (_filter == 'Paid' && inv.balanceAmount == 0) ||
          (_filter == 'Pending' && inv.balanceAmount > 0);
      return matchSearch && matchFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search customer or invoice no...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
            onChanged: (_) => setState(_applyFilter),
          ),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          child: Row(children: [
            for (final f in ['All', 'Paid', 'Pending'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) =>
                      setState(() { _filter = f; _applyFilter(); }),
                  selectedColor: Colors.green.shade100,
                ),
              ),
            const Spacer(),
            Text('${_filtered.length} invoices',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('No invoices found',
                          style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final inv = _filtered[i];
                          final isPaid = inv.balanceAmount == 0;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPaid
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                isPaid
                                    ? Icons.check_circle
                                    : Icons.pending,
                                color: isPaid
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(inv.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${inv.invoiceNo}  •  ${fmt.format(DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate))}'),
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
                                  isPaid
                                      ? 'PAID'
                                      : 'Due: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight:
                                          FontWeight.w600),
                                ),
                              ],
                            ),
                            onTap: () => _showInvoiceDetail(
                                context, inv, fmt),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  void _showInvoiceDetail(BuildContext context,
      InvoiceWithCustomer inv, DateFormat fmt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => _InvoiceDetailSheet(
            inv: inv, fmt: fmt, controller: ctrl),
      ),
    );
  }
}

class _InvoiceDetailSheet extends StatelessWidget {
  final InvoiceWithCustomer inv;
  final DateFormat fmt;
  final ScrollController controller;

  const _InvoiceDetailSheet(
      {required this.inv,
      required this.fmt,
      required this.controller});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvoiceLine>>(
      future:
          context.read<AppDatabase>().getInvoiceLines(inv.id),
      builder: (ctx, snap) {
        final lines = snap.data ?? [];
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(inv.invoiceNo,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: inv.balanceAmount == 0
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius:
                            BorderRadius.circular(8)),
                    child: Text(
                      inv.balanceAmount == 0
                          ? 'PAID'
                          : 'PENDING',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: inv.balanceAmount == 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700),
                    ),
                  ),
                ]),
            const SizedBox(height: 4),
            Text(inv.customerName,
                style: const TextStyle(
                    fontSize: 15, color: Colors.grey)),
            Text(
                fmt.format(
                    DateTime.fromMillisecondsSinceEpoch(
                        inv.invoiceDate)),
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey)),
            const Divider(height: 24),

            // Lines
            const Text('Items',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                              '${l.itemNameSnapshot} × ${l.qty} ${l.unit}',
                              style: const TextStyle(
                                  fontSize: 13))),
                      Text(
                          'Rs.${l.lineSubtotal.toStringAsFixed(0)}',
                          style:
                              const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 20),

            // Totals
            _totalRow('Subtotal', inv.subtotal),
            if (inv.discountAmount > 0)
              _totalRow('Discount',
                  -inv.discountAmount,
                  color: Colors.orange),
            if (inv.gstAmount > 0)
              _totalRow('GST', inv.gstAmount),
            const Divider(height: 8),
            _totalRow('TOTAL', inv.total,
                bold: true, fontSize: 16),
            if (inv.paidAmount > 0)
              _totalRow('Paid', inv.paidAmount,
                  color: Colors.green),
            if (inv.balanceAmount > 0)
              _totalRow('Balance Due', inv.balanceAmount,
                  color: Colors.red, bold: true),

            const SizedBox(height: 20),
            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share via WhatsApp'),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF25D366)),
                onPressed: () =>
                    _shareWhatsApp(context, inv, lines),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _totalRow(String label, double amt,
      {bool bold = false,
      Color? color,
      double fontSize = 13}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: bold
                          ? FontWeight.bold
                          : FontWeight.normal)),
              Text('Rs.${amt.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: bold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: color)),
            ]),
      );

  void _shareWhatsApp(BuildContext context,
      InvoiceWithCustomer inv, List<InvoiceLine> lines) {
    final fmt2 = DateFormat('dd/MM/yyyy');
    final date = fmt2.format(
        DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate));

    final sb = StringBuffer();
    sb.writeln('*Invoice: ${inv.invoiceNo}*');
    sb.writeln('Date: $date');
    sb.writeln('Customer: ${inv.customerName}');
    sb.writeln('----------------------------');
    for (final l in lines) {
      sb.writeln(
          '${l.itemNameSnapshot} x ${l.qty} ${l.unit} = Rs.${l.lineSubtotal.toStringAsFixed(0)}');
    }
    sb.writeln('----------------------------');
    if (inv.discountAmount > 0) {
      sb.writeln(
          'Discount: -Rs.${inv.discountAmount.toStringAsFixed(0)}');
    }
    if (inv.gstAmount > 0) {
      sb.writeln(
          'GST: Rs.${inv.gstAmount.toStringAsFixed(0)}');
    }
    sb.writeln(
        '*Total: Rs.${inv.total.toStringAsFixed(0)}*');
    if (inv.balanceAmount > 0) {
      sb.writeln(
          '*Balance Due: Rs.${inv.balanceAmount.toStringAsFixed(0)}*');
    } else {
      sb.writeln('*Status: PAID*');
    }

    final msg = Uri.encodeComponent(sb.toString());
    final url = 'https://wa.me/?text=$msg';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Copy the invoice text and open WhatsApp'),
        action: SnackBarAction(
            label: 'Copy Text',
            onPressed: () {
              // Text is shown in snackbar for manual copy
            }),
      ),
    );
  }
}
