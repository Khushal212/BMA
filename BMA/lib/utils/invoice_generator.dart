import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class InvoiceGenerator {
  static Future<pw.Document> generateInvoicePDF({
    required String invoiceNo,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String invoiceDate,
    required List<InvoiceLineData> lines,
    required double subtotal,
    required double discountPercent,
    required double discountAmount,
    required double gstAmount,
    required double total,
    required double paidAmount,
    required double balanceAmount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BUSINESS MANAGEMENT APP',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Vegetable Wholesaler'),
                    ],
                  ),
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice No: $invoiceNo',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: $invoiceDate'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Bill To:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Customer Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(''),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(customerName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Phone: $customerPhone'),
                      pw.Text('Address: $customerAddress'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Items Table
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Unit', 'Rate', 'Amount'],
                data: lines
                    .map((line) => [
                          line.itemName,
                          line.qty.toStringAsFixed(2),
                          line.unit,
                          '₹${line.rate.toStringAsFixed(2)}',
                          '₹${(line.qty * line.rate).toStringAsFixed(2)}',
                        ])
                    .toList(),
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Subtotal: '),
                          pw.SizedBox(width: 100),
                          pw.Text('₹${subtotal.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      if (discountPercent > 0)
                        pw.Row(
                          children: [
                            pw.Text('Discount ($discountPercent%): '),
                            pw.SizedBox(width: 80),
                            pw.Text('-₹${discountAmount.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      pw.Row(
                        children: [
                          pw.Text('GST (18%): '),
                          pw.SizedBox(width: 100),
                          pw.Text('₹${gstAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        children: [
                          pw.Text('TOTAL: ',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              )),
                          pw.SizedBox(width: 120),
                          pw.Text('₹${total.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              )),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          pw.Text('Paid: '),
                          pw.SizedBox(width: 120),
                          pw.Text('₹${paidAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('Balance: ',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 115),
                          pw.Text('₹${balanceAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: balanceAmount > 0 ? PdfColors.red : PdfColors.green,
                              )),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // Footer
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 1)),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Seller Signature', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text('_________________'),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text('Buyer Signature', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text('_________________'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}

class InvoiceLineData {
  final String itemName;
  final double qty;
  final String unit;
  final double rate;

  InvoiceLineData({
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.rate,
  });
}
