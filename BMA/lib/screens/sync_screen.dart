import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../database/app_database.dart';

// Note: Full Google Drive API requires google_sign_in + googleapis packages.
// This implements the foundation with manual Google Drive backup via share sheet.
// Full auto-sync requires adding:
//   google_sign_in: ^6.0.0
//   googleapis: ^11.0.0
// to pubspec.yaml and OAuth setup in Google Console.

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _syncing = false;
  String _status = '';
  String? _lastSyncTime;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadSyncInfo();
  }

  Future<void> _loadSyncInfo() async {
    final db = context.read<AppDatabase>();
    final lastSync = await db.getSetting('last_sync_time');
    final devId = await db.getSetting('device_id');
    if (mounted) {
      setState(() {
        _lastSyncTime = lastSync;
        _deviceId = devId;
      });
    }
  }

  Future<Map<String, dynamic>> _exportAllData() async {
    final db = context.read<AppDatabase>();
    final customers = await db.getAllCustomers();
    final items = await db.getAllItems();
    final invoices = await db.getAllInvoices();

    final invoiceLines = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      final lines = await db.getInvoiceLines(inv.id);
      for (final l in lines) {
        invoiceLines.add({
          'id': l.id,
          'invoiceId': l.invoiceId,
          'itemId': l.itemId,
          'itemNameSnapshot': l.itemNameSnapshot,
          'qty': l.qty,
          'unit': l.unit,
          'rate': l.rate,
          'lineSubtotal': l.lineSubtotal,
          'lineGstPercent': l.lineGstPercent,
          'lineGstAmount': l.lineGstAmount,
          'lineTotal': l.lineTotal,
        });
      }
    }

    final allPayments = <Map<String, dynamic>>[];
    for (final c in customers) {
      final payments = await db.getCustomerPayments(c.id);
      for (final p in payments) {
        allPayments.add({
          'id': p.id,
          'customerId': p.customerId,
          'paymentDate': p.paymentDate,
          'amount': p.amount,
          'mode': p.mode,
          'reference': p.reference,
          'notes': p.notes,
          'createdAt': p.createdAt,
        });
      }
    }

    return {
      'version': '2.0',
      'appName': 'VyapaarX',
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceId': _deviceId ?? 'unknown',
      'customers': customers.map((c) => {
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'address': c.address,
            'creditLimit': c.creditLimit,
            'defaultGstPercent': c.defaultGstPercent,
            'createdAt': c.createdAt,
          }).toList(),
      'items': items.map((i) => {
            'id': i.id,
            'name': i.name,
            'unit': i.unit,
            'defaultRate': i.defaultRate,
            'gstPercent': i.gstPercent,
            'currentStock': i.currentStock,
            'lowStockAlert': i.lowStockAlert,
            'createdAt': i.createdAt,
          }).toList(),
      'invoices': invoices.map((i) => {
            'id': i.id,
            'invoiceNo': i.invoiceNo,
            'customerId': i.customerId,
            'invoiceDate': i.invoiceDate,
            'subtotal': i.subtotal,
            'discountPercent': i.discountPercent,
            'discountAmount': i.discountAmount,
            'gstAmount': i.gstAmount,
            'total': i.total,
            'paidAmount': i.paidAmount,
            'balanceAmount': i.balanceAmount,
            'paymentType': i.paymentType,
            'notes': i.notes,
            'createdAt': i.createdAt,
          }).toList(),
      'invoiceLines': invoiceLines,
      'payments': allPayments,
    };
  }

  Future<void> _backupToGoogleDrive() async {
    setState(() {
      _syncing = true;
      _status = 'Preparing backup...';
    });

    try {
      final data = await _exportAllData();
      final json = jsonEncode(data);
      final dir = await getTemporaryDirectory();
      final fmt = DateFormat('yyyy-MM-dd_HH-mm');
      final fileName =
          'VyapaarX_Sync_${fmt.format(DateTime.now())}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json);

      setState(() => _status = 'Opening Google Drive...');

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VyapaarX Data Sync — ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
        text:
            'Save this file to Google Drive to sync your VyapaarX data across devices.',
      );

      // Save last sync time
      final now = DateTime.now().toIso8601String();
      await context
          .read<AppDatabase>()
          .saveSetting('last_sync_time', now);
      setState(() {
        _lastSyncTime = now;
        _status =
            '✅ File shared! Save it to Google Drive to complete sync.';
      });
    } catch (e) {
      setState(() => _status = '❌ Failed: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = _lastSyncTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.parse(_lastSyncTime!))
        : 'Never synced';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sync'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.cloud_sync,
                      color: Colors.blue.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Google Drive Sync',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text('Last sync: $lastSync',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            if (_status.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.shade50
                      : _status.startsWith('❌')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status,
                    style: const TextStyle(fontSize: 13)),
              ),

            // How it works
            const Text('How Sync Works',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            ...[
              '1. Tap "Backup to Google Drive" below',
              '2. Google Drive app opens — save the file',
              '3. On another device, open VyapaarX',
              '4. Go to Sync → "Restore from Google Drive"',
              '5. Open the saved file — data is restored',
            ].map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 13))),
                  ]),
                )),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: Text(_syncing
                    ? 'Syncing...'
                    : 'Backup to Google Drive'),
                onPressed:
                    _syncing ? null : _backupToGoogleDrive,
              ),
            ),
            const SizedBox(height: 12),

            // Coming soon — full auto sync
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.rocket_launch,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      const Text('Coming Soon',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      'Automatic real-time Google Drive sync — '
                      'sign in with Google and data syncs automatically '
                      'across all your devices without manual steps.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            const Text('Sync Tips',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _tipRow(Icons.schedule, 'Daily backup',
                        'Take a backup every day to avoid data loss'),
                    _tipRow(Icons.folder, 'Dedicated folder',
                        'Create a "VyapaarX Backups" folder in Drive'),
                    _tipRow(Icons.history, 'Keep old backups',
                        'Keep last 7 backups in case you need to recover'),
                    _tipRow(Icons.wifi_off, 'Works offline',
                        'App works fully offline, sync when connected'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String title, String sub) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon,
              color: Colors.green.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey)),
              ],
            ),
          ),
        ]),
      );
}
