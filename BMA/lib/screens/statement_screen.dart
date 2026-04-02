import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({Key? key}) : super(key: key);
  @override
  State<StatementScreen> createState() =>
      _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  List<Customer> _customers = [];
  Customer? _selected;
  DateTime _from = DateTime.now()
      .subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final list =
        await context.read<AppDatabase>().getAllCustomers();
    if (mounted) setState(() => _customers = list);
  }

  Future<pw.Document> _buildPdf(Customer customer) async {
    final db = context.read<AppDatabase>();
    final fmt = DateFormat('dd MMM yyyy');
    final shopName =
        await db.getSetting('shop_name') ?? 'VyapaarX';
    final shopPhone =
        await db.getSetting('shop_phone') ?? '';
    final shopAddress =
        await db.getSetting('shop_address') ?? '';

    final start = DateTime(_from.year, _from.month, _from.day)
        .millisecondsSinceEpoch;
    final end =
        DateTime(_to.year, _to.month, _to.day, 23, 59, 59)
            .millisecondsSinceEpoch;

    final allInvoices =
        await db.getCustomerInvoices(customer.id);
    final periodInvoices = allInvoices
        .where((i) =>
            i.invoiceDate >= start && i.invoiceDate <= end)
        .toList()
      ..sort((a, b) =>
          a.invoiceDate.compareTo(b.invoiceDate));

    final allPayments =
        await db.getCustomerPayments(customer.id);
    final periodPayments = allPayments
        .where((p) =>
            p.paymentDate >= start && p.paymentDate <= end)
        .toList()
      ..sort((a, b) =>
          a.paymentDate.compareTo(b.paymentDate));

    final totalInvoiced = periodInvoices.fold(
        0.0, (s, i) => s + i.total);
    final totalPaid = periodPayments.fold(
        0.0, (s, p) => s + p.amount);
    final outstanding =
        await db.getCustomerOutstanding(customer.id);

    // Build ledger entries
    final entries = <Map<String, dynamic>>[];
    double runningBalance = 0;

    // Merge invoices and payments by date
    final allEntries = <Map<String, dynamic>>[];
    for (final inv in periodInvoices) {
      allEntries.add({
        'date': inv.invoiceDate,
        'type': 'INVOICE',
        'desc': inv.invoiceNo,
        'debit': inv.total,
        'credit': 0.0,
      });
    }
    for (final pay in periodPayments) {
      allEntries.add({
        'date': pay.paymentDate,
        'type': 'PAYMENT',
        'desc': '${pay.mode}${pay.reference != null ? " - ${pay.reference}" : ""}',
        'debit': 0.0,
        'credit': pay.amount,
      });
    }
    allEntries.sort(
        (a, b) => (a['date'] as int).compareTo(b['date'] as int));

    for (final e in allEntries) {
      runningBalance += (e['debit'] as double) -
          (e['credit'] as double);
      entries.add({...e, 'balance': runningBalance});
    }

    // Build PDF
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
              color: PdfColors.green700,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shopName,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold)),
                    if (shopPhone.isNotEmpty)
                      pw.Text('+91 $shopPhone',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10)),
                    if (shopAddress.isNotEmpty)
                      pw.Text(shopAddress,
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10)),
                  ]),
              pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('STATEMENT OF ACCOUNT',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        '${fmt.format(_from)} to ${fmt.format(_to)}',
                        style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10)),
                  ]),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Customer info
        pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TO',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(customer.name,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('+91 ${customer.phone}',
                        style: const pw.TextStyle(
                            fontSize: 10)),
                    if (customer.address != null)
                      pw.Text(customer.address!,
                          style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600)),
                  ]),
              pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: outstanding > 0
                              ? PdfColors.red
                              : PdfColors.green,
                          width: 1.5),
                      borderRadius:
                          const pw.BorderRadius.all(
                              pw.Radius.circular(6))),
                  child: pw.Column(children: [
                    pw.Text(
                        outstanding > 0
                            ? 'AMOUNT DUE'
                            : 'CLEAR',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: outstanding > 0
                                ? PdfColors.red
                                : PdfColors.green)),
                    pw.Text(
                        'Rs.${outstanding.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: outstanding > 0
                                ? PdfColors.red
                                : PdfColors.green)),
                  ])),
            ]),
        pw.SizedBox(height: 14),

        // Ledger table
        pw.TableHelper.fromTextArray(
          headers: [
            'Date', 'Description', 'Invoice (Dr)', 'Payment (Cr)', 'Balance'
          ],
          data: entries.map((e) => [
            DateFormat('dd/MM/yy').format(
                DateTime.fromMillisecondsSinceEpoch(
                    e['date'] as int)),
            e['desc'],
            (e['debit'] as double) > 0
                ? 'Rs.${(e['debit'] as double).toStringAsFixed(2)}'
                : '-',
            (e['credit'] as double) > 0
                ? 'Rs.${(e['credit'] as double).toStringAsFixed(2)}'
                : '-',
            'Rs.${(e['balance'] as double).toStringAsFixed(2)}',
          ]).toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green700),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: pw.TableBorder.all(
              color: PdfColors.grey300, width: 0.5),
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColors.grey100),
        ),
        pw.SizedBox(height: 14),

        // Summary
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                  width: 240,
                  child: pw.Column(children: [
                    _pdfTotalRow('Total Invoiced',
                        'Rs.${totalInvoiced.toStringAsFixed(2)}'),
                    _pdfTotalRow('Total Paid',
                        'Rs.${totalPaid.toStringAsFixed(2)}',
                        valueColor: PdfColors.green700),
                    pw.Divider(color: PdfColors.grey400),
                    _pdfTotalRow(
                        'Balance Due',
                        'Rs.${outstanding.toStringAsFixed(2)}',
                        bold: true,
                        valueColor: outstanding > 0
                            ? PdfColors.red
                            : PdfColors.green700),
                  ])),
            ]),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
              'Generated by VyapaarX • Smart Business Management',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500)),
        ),
      ],
    ));

    return pdf;
  }

  pw.Widget _pdfTotalRow(String label, String value,
      {bool bold = false, PdfColor? valueColor}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: bold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: bold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: valueColor)),
            ]),
      );

  Future<void> _viewPdf() async {
    if (_selected == null) return;
    final pdf = await _buildPdf(_selected!);
    await Printing.layoutPdf(
      name:
          'Statement_${_selected!.name}_${DateFormat('MMMyyyy').format(_from)}',
      onLayout: (_) => pdf.save(),
    );
  }

  Future<void> _shareWhatsApp() async {
    if (_selected == null) return;
    final db = context.read<AppDatabase>();
    final shopName =
        await db.getSetting('shop_name') ?? 'VyapaarX';
    final fmt = DateFormat('dd MMM yyyy');
    final outstanding =
        await db.getCustomerOutstanding(_selected!.id);

    final msg = Uri.encodeComponent(
      '📊 *Statement of Account*\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '👤 Dear *${_selected!.name}*,\n\n'
      'Please find your account statement below:\n\n'
      '📅 Period: ${fmt.format(_from)} to ${fmt.format(_to)}\n'
      '💰 *Balance Due: Rs.${outstanding.toStringAsFixed(0)}*\n\n'
      'Kindly clear the outstanding amount.\n\n'
      '— *$shopName*\n'
      '_Sent via VyapaarX_',
    );

    final url = Uri.parse(
        'whatsapp://send?phone=91${_selected!.phone}&text=$msg');
    final fallback = Uri.parse(
        'https://wa.me/91${_selected!.phone}?text=$msg');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(fallback,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Statement'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer selector
            DropdownButtonFormField<String>(
              value: _selected?.id,
              decoration: const InputDecoration(
                labelText: 'Select Customer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _customers
                  .map((c) => DropdownMenuItem(
                      value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selected = _customers
                    .firstWhere((c) => c.id == v);
              }),
            ),
            const SizedBox(height: 12),

            // Date range
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range, size: 16),
              label: Text(
                  '${fmt.format(_from)} → ${fmt.format(_to)}'),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      DateTimeRange(start: _from, end: _to),
                );
                if (range != null) {
                  setState(() {
                    _from = range.start;
                    _to = range.end;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            if (_selected != null) ...[
              FutureBuilder<double>(
                future: context
                    .read<AppDatabase>()
                    .getCustomerOutstanding(_selected!.id),
                builder: (ctx, snap) {
                  final out = snap.data ?? 0;
                  return Card(
                    color: out > 0
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(
                          out > 0
                              ? Icons.warning
                              : Icons.check_circle,
                          color: out > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(_selected!.name,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              Text('+91 ${_selected!.phone}',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs.${out.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: out > 0
                                      ? Colors.red
                                      : Colors.green),
                            ),
                            Text(
                              out > 0
                                  ? 'Outstanding'
                                  : 'All Clear',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: out > 0
                                      ? Colors.red
                                      : Colors.green),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.picture_as_pdf),
                  label: const Text(
                      'View / Print Statement PDF'),
                  onPressed: _loading ? null : _viewPdf,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text(
                      'Send Statement via WhatsApp'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF25D366)),
                  onPressed: _shareWhatsApp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
