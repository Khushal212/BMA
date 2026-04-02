import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../database/app_database.dart';

class GstReportScreen extends StatefulWidget {
  const GstReportScreen({Key? key}) : super(key: key);
  @override
  State<GstReportScreen> createState() =>
      _GstReportScreenState();
}

class _GstSlab {
  final double rate;
  double taxableAmount;
  double cgst;
  double sgst;
  double totalGst;
  int invoiceCount;

  _GstSlab(this.rate)
      : taxableAmount = 0,
        cgst = 0,
        sgst = 0,
        totalGst = 0,
        invoiceCount = 0;
}

class _GstReportScreenState extends State<GstReportScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _loading = false;
  Map<double, _GstSlab> _slabs = {};
  double _totalTaxable = 0;
  double _totalGst = 0;
  double _totalRevenue = 0;
  int _totalInvoices = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();

    final start =
        DateTime(_year, _month, 1).millisecondsSinceEpoch;
    final end =
        DateTime(_year, _month + 1, 0, 23, 59, 59)
            .millisecondsSinceEpoch;

    final allInvoices = await db.getAllInvoices();
    final monthInvoices = allInvoices.where((i) =>
        i.invoiceDate >= start && i.invoiceDate <= end);

    final slabs = <double, _GstSlab>{};
    double totalTaxable = 0,
        totalGst = 0,
        totalRevenue = 0;
    int totalInvoices = 0;

    for (final inv in monthInvoices) {
      totalRevenue += inv.total;
      totalInvoices++;
      final lines = await db.getInvoiceLines(inv.id);
      for (final l in lines) {
        if (l.lineGstPercent > 0) {
          slabs.putIfAbsent(
              l.lineGstPercent, () => _GstSlab(l.lineGstPercent));
          final slab = slabs[l.lineGstPercent]!;
          slab.taxableAmount += l.lineSubtotal;
          slab.totalGst += l.lineGstAmount;
          slab.cgst += l.lineGstAmount / 2;
          slab.sgst += l.lineGstAmount / 2;
          slab.invoiceCount++;
          totalTaxable += l.lineSubtotal;
          totalGst += l.lineGstAmount;
        }
      }
    }

    if (mounted) {
      setState(() {
        _slabs = slabs;
        _totalTaxable = totalTaxable;
        _totalGst = totalGst;
        _totalRevenue = totalRevenue;
        _totalInvoices = totalInvoices;
        _loading = false;
      });
    }
  }

  Future<void> _printReport() async {
    final shopName = await context
            .read<AppDatabase>()
            .getSetting('shop_name') ??
        'VyapaarX';
    final shopGstin = await context
            .read<AppDatabase>()
            .getSetting('shop_gstin') ??
        '';
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(_year, _month));
    final slabList = _slabs.values.toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));

    await Printing.layoutPdf(
      name: 'GST_Report_$monthName',
      onLayout: (_) async {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6)),
                ),
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
                                fontWeight:
                                    pw.FontWeight.bold)),
                        if (shopGstin.isNotEmpty)
                          pw.Text('GSTIN: $shopGstin',
                              style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('GST REPORT',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 16,
                                fontWeight:
                                    pw.FontWeight.bold)),
                        pw.Text(monthName,
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Summary
              pw.Row(children: [
                _pdfCard('Total Revenue',
                    'Rs.${_totalRevenue.toStringAsFixed(2)}'),
                pw.SizedBox(width: 8),
                _pdfCard('Taxable Amount',
                    'Rs.${_totalTaxable.toStringAsFixed(2)}'),
                pw.SizedBox(width: 8),
                _pdfCard('Total GST Collected',
                    'Rs.${_totalGst.toStringAsFixed(2)}'),
              ]),
              pw.SizedBox(height: 16),

              // Slab-wise table
              pw.Text('GST Slab-wise Summary',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: [
                  'GST Rate', 'Taxable Amt', 'CGST',
                  'SGST', 'Total GST'
                ],
                data: [
                  ...slabList.map((s) => [
                    '${s.rate.toStringAsFixed(0)}%',
                    'Rs.${s.taxableAmount.toStringAsFixed(2)}',
                    'Rs.${s.cgst.toStringAsFixed(2)}',
                    'Rs.${s.sgst.toStringAsFixed(2)}',
                    'Rs.${s.totalGst.toStringAsFixed(2)}',
                  ]),
                  // Total row
                  [
                    'TOTAL',
                    'Rs.${_totalTaxable.toStringAsFixed(2)}',
                    'Rs.${(_totalGst / 2).toStringAsFixed(2)}',
                    'Rs.${(_totalGst / 2).toStringAsFixed(2)}',
                    'Rs.${_totalGst.toStringAsFixed(2)}',
                  ],
                ],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 10),
                headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100),
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                    'Generated by VyapaarX',
                    style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500)),
              ),
            ],
          ),
        ));
        return pdf.save();
      },
    );
  }

  pw.Widget _pdfCard(String label, String value) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            border: pw.Border.all(
                color: PdfColors.green200, width: 0.5),
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(_year, _month));
    final slabList = _slabs.values.toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Report'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Print / Export PDF',
            onPressed: _slabs.isEmpty ? null : _printReport,
          ),
        ],
      ),
      body: Column(children: [
        // Month selector
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    if (_month == 1) {
                      _month = 12;
                      _year--;
                    } else {
                      _month--;
                    }
                  });
                  _load();
                },
              ),
              Text(monthName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    DateTime(_year, _month).isBefore(
                            DateTime(now.year, now.month))
                        ? () {
                            setState(() {
                              if (_month == 12) {
                                _month = 1;
                                _year++;
                              } else {
                                _month++;
                              }
                            });
                            _load();
                          }
                        : null,
              ),
            ],
          ),
        ),

        if (_loading)
          const Expanded(
              child:
                  Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  Row(children: [
                    Expanded(
                        child: _SummaryCard(
                            'Total Revenue',
                            'Rs.${_totalRevenue.toStringAsFixed(0)}',
                            Colors.blue,
                            Icons.currency_rupee)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _SummaryCard(
                            'GST Collected',
                            'Rs.${_totalGst.toStringAsFixed(0)}',
                            Colors.green,
                            Icons.receipt)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _SummaryCard(
                            'CGST',
                            'Rs.${(_totalGst / 2).toStringAsFixed(0)}',
                            Colors.purple,
                            Icons.percent)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _SummaryCard(
                            'SGST',
                            'Rs.${(_totalGst / 2).toStringAsFixed(0)}',
                            Colors.orange,
                            Icons.percent)),
                  ]),

                  const SizedBox(height: 20),

                  if (slabList.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                            'No GST transactions this month',
                            style: TextStyle(
                                color: Colors.grey)),
                      ),
                    )
                  else ...[
                    const Text('Slab-wise Breakdown',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 12),
                    ...slabList.map((s) => Card(
                          margin: const EdgeInsets.only(
                              bottom: 10),
                          child: Padding(
                            padding:
                                const EdgeInsets.all(16),
                            child: Column(children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            horizontal: 12,
                                            vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .green.shade100,
                                      borderRadius:
                                          BorderRadius
                                              .circular(6),
                                    ),
                                    child: Text(
                                      'GST @ ${s.rate.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          color: Colors
                                              .green.shade700,
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    'Rs.${s.totalGst.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 18),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(children: [
                                Expanded(
                                    child: _InfoRow(
                                        'Taxable Amount',
                                        'Rs.${s.taxableAmount.toStringAsFixed(2)}')),
                                Expanded(
                                    child: _InfoRow('CGST',
                                        'Rs.${s.cgst.toStringAsFixed(2)}')),
                                Expanded(
                                    child: _InfoRow('SGST',
                                        'Rs.${s.sgst.toStringAsFixed(2)}')),
                              ]),
                            ]),
                          ),
                        )),

                    // Grand total row
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GRAND TOTAL GST',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 15)),
                            Text(
                              'Rs.${_totalGst.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color:
                                      Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                          Icons.picture_as_pdf),
                      label: const Text(
                          'Export GST Report PDF'),
                      onPressed: _slabs.isEmpty
                          ? null
                          : _printReport,
                    ),
                  ),
                ],
              ),
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
  const _SummaryCard(
      this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      );
}
