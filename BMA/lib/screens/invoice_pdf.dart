import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../database/app_database.dart';

class InvoicePdfGenerator {
  static Future<Uint8List> generate({
    required InvoiceWithCustomer inv,
    required List<InvoiceLine> lines,
    required Map<String, String> shopInfo,
  }) async {
    final pdf = pw.Document();

    // Shop info
    final shopName = shopInfo['shop_name'] ?? 'VyapaarX';
    final shopAddress = shopInfo['shop_address'] ?? '';
    final shopPhone = shopInfo['shop_phone'] ?? '';
    final shopGstin = shopInfo['shop_gstin'] ?? '';
    final shopUpi = shopInfo['shop_upi'] ?? '';

    // Generate UPI QR image if UPI set
    Uint8List? qrBytes;
    if (shopUpi.isNotEmpty && shopUpi.contains('@')) {
      final upiUrl =
          'upi://pay?pa=$shopUpi&pn=${Uri.encodeComponent(shopName)}'
          '&am=${inv.total.toStringAsFixed(2)}&cu=INR'
          '&tn=${Uri.encodeComponent(inv.invoiceNo)}';
      qrBytes = await _generateQrBytes(upiUrl);
    }

    final dateStr = _formatDate(inv.invoiceDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green700,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
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
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold)),
                      if (shopAddress.isNotEmpty)
                        pw.Text(shopAddress,
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10)),
                      if (shopPhone.isNotEmpty)
                        pw.Text('Ph: +91 $shopPhone',
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 10)),
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
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(inv.invoiceNo,
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 12)),
                      pw.Text('Date: $dateStr',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── BILL TO ──────────────────────────────────────
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILL TO',
                        style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv.customerName,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _statusBadge(inv.balanceAmount == 0
                        ? 'PAID'
                        : 'PENDING'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── ITEMS TABLE ───────────────────────────────────
            pw.TableHelper.fromTextArray(
              headers: [
                '#', 'Item', 'Qty', 'Unit', 'Rate', 'GST%', 'Amount'
              ],
              data: lines.asMap().entries.map((e) {
                final i = e.key + 1;
                final l = e.value;
                return [
                  '$i',
                  l.itemNameSnapshot,
                  l.qty.toStringAsFixed(2),
                  l.unit,
                  'Rs.${l.rate.toStringAsFixed(2)}',
                  '${l.lineGstPercent.toStringAsFixed(0)}%',
                  'Rs.${l.lineTotal.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green700),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
                6: pw.Alignment.centerRight,
              },
              oddRowDecoration: pw.BoxDecoration(
                  color: PdfColors.grey100),
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
            ),
            pw.SizedBox(height: 16),

            // ── TOTALS + QR ────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // QR code side
                if (qrBytes != null)
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(pw.MemoryImage(qrBytes),
                          width: 90, height: 90),
                      pw.SizedBox(height: 4),
                      pw.Text('Scan to Pay',
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600)),
                      pw.Text(shopUpi,
                          style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.green700)),
                    ],
                  )
                else
                  pw.SizedBox(width: 90),

                // Totals side
                pw.Container(
                  width: 220,
                  child: pw.Column(children: [
                    _totalRow('Subtotal',
                        'Rs.${inv.subtotal.toStringAsFixed(2)}'),
                    if (inv.discountAmount > 0)
                      _totalRow(
                          'Discount',
                          '-Rs.${inv.discountAmount.toStringAsFixed(2)}',
                          valueColor: PdfColors.orange),
                    if (inv.gstAmount > 0)
                      _totalRow('GST',
                          'Rs.${inv.gstAmount.toStringAsFixed(2)}'),
                    pw.Divider(color: PdfColors.grey400),
                    _totalRow(
                        'TOTAL',
                        'Rs.${inv.total.toStringAsFixed(2)}',
                        bold: true, fontSize: 13),
                    if (inv.paidAmount > 0)
                      _totalRow('Paid',
                          'Rs.${inv.paidAmount.toStringAsFixed(2)}',
                          valueColor: PdfColors.green700),
                    if (inv.balanceAmount > 0) ...[
                      pw.Divider(color: PdfColors.grey400),
                      _totalRow(
                          'Balance Due',
                          'Rs.${inv.balanceAmount.toStringAsFixed(2)}',
                          bold: true,
                          valueColor: PdfColors.red,
                          fontSize: 12),
                    ],
                  ]),
                ),
              ],
            ),

            pw.Spacer(),

            // ── FOOTER ────────────────────────────────────────
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer Signature',
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600)),
                    pw.SizedBox(height: 24),
                    pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.grey400),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Authorized Signature',
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600)),
                    pw.SizedBox(height: 24),
                    pw.Container(
                        width: 120,
                        height: 1,
                        color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text(shopName,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                  'Generated by VyapaarX • Smart Business Management',
                  style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500)),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false,
      PdfColor? valueColor,
      double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: valueColor)),
        ],
      ),
    );
  }

  static pw.Widget _statusBadge(String text) {
    final isPaid = text == 'PAID';
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
      decoration: pw.BoxDecoration(
        color: isPaid ? PdfColors.green100 : PdfColors.orange100,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(
            color: isPaid
                ? PdfColors.green700
                : PdfColors.orange700),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color:
              isPaid ? PdfColors.green700 : PdfColors.orange700,
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  static Future<Uint8List> _generateQrBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
    );
    final img = await qrPainter.toImage(200);
    final byteData =
        await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static String _formatDate(int milliseconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
