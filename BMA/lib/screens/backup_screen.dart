import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import '../database/app_database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  String _status = '';
  List<File> _localBackups = [];

  @override
  void initState() {
    super.initState();
    _loadBackupList();
  }

  Future<void> _loadBackupList() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (await backupDir.exists()) {
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      if (mounted) setState(() => _localBackups = files);
    }
  }

  Future<Map<String, dynamic>> _exportData() async {
    final db = context.read<AppDatabase>();
    final customers = await db.getAllCustomers();
    final items = await db.getAllItems();
    final invoices = await db.getAllInvoices();

    final invoiceLines = <Map<String, dynamic>>[];
    for (final inv in invoices) {
      final lines = await db.getInvoiceLines(inv.id);
      for (final l in lines) {
        invoiceLines.add({
          'id': l.id, 'invoiceId': l.invoiceId,
          'itemId': l.itemId,
          'itemNameSnapshot': l.itemNameSnapshot,
          'qty': l.qty, 'unit': l.unit, 'rate': l.rate,
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
          'id': p.id, 'customerId': p.customerId,
          'paymentDate': p.paymentDate, 'amount': p.amount,
          'mode': p.mode, 'reference': p.reference,
          'notes': p.notes, 'createdAt': p.createdAt,
        });
      }
    }

    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'VyapaarX',
      'customers': customers.map((c) => {
        'id': c.id, 'name': c.name, 'phone': c.phone,
        'address': c.address, 'creditLimit': c.creditLimit,
        'defaultGstPercent': c.defaultGstPercent,
        'createdAt': c.createdAt,
      }).toList(),
      'items': items.map((i) => {
        'id': i.id, 'name': i.name, 'unit': i.unit,
        'defaultRate': i.defaultRate,
        'gstPercent': i.gstPercent,
        'currentStock': i.currentStock,
        'lowStockAlert': i.lowStockAlert,
        'createdAt': i.createdAt,
      }).toList(),
      'invoices': invoices.map((i) => {
        'id': i.id, 'invoiceNo': i.invoiceNo,
        'customerId': i.customerId,
        'invoiceDate': i.invoiceDate,
        'subtotal': i.subtotal,
        'discountPercent': i.discountPercent,
        'discountAmount': i.discountAmount,
        'gstAmount': i.gstAmount, 'total': i.total,
        'paidAmount': i.paidAmount,
        'balanceAmount': i.balanceAmount,
        'paymentType': i.paymentType,
        'notes': i.notes, 'createdAt': i.createdAt,
      }).toList(),
      'invoiceLines': invoiceLines,
      'payments': allPayments,
    };
  }

  Future<void> _createLocalBackup() async {
    setState(() { _loading = true; _status = 'Creating backup...'; });
    try {
      final data = await _exportData();
      final json = jsonEncode(data);
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create();
      final fileName =
          'vyapaarx_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(json);
      setState(() => _status = '✅ Backup saved: $fileName');
      await _loadBackupList();
    } catch (e) {
      setState(() => _status = '❌ Backup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _shareBackup() async {
    setState(() { _loading = true; _status = 'Preparing backup...'; });
    try {
      final data = await _exportData();
      final json = jsonEncode(data);
      final dir = await getTemporaryDirectory();
      final fileName =
          'vyapaarx_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VyapaarX Backup - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
        text: 'VyapaarX data backup. Import this file to restore your data.',
      );
      setState(() => _status = '✅ Backup shared successfully');
    } catch (e) {
      setState(() => _status = '❌ Share failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Restore Backup?'),
        content: const Text(
            'This will ADD the backed-up data to your current data. '
            'Existing records will not be deleted. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _loading = true; _status = 'Restoring...'; });
    try {
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final db = context.read<AppDatabase>();

      int restored = 0;
      // Restore customers
      for (final c in (data['customers'] as List)) {
        final existing = await db.getCustomer(c['id']);
        if (existing == null) {
          await db.createCustomer(
            id: c['id'], name: c['name'], phone: c['phone'],
            address: c['address'],
            creditLimit: (c['creditLimit'] as num).toDouble(),
            defaultGstPercent:
                (c['defaultGstPercent'] as num).toDouble(),
          );
          restored++;
        }
      }
      // Restore items
      for (final i in (data['items'] as List)) {
        final existing = await db.getItem(i['id']);
        if (existing == null) {
          await db.createItem(
            id: i['id'], name: i['name'], unit: i['unit'],
            defaultRate: i['defaultRate'] != null
                ? (i['defaultRate'] as num).toDouble() : null,
            gstPercent: (i['gstPercent'] as num).toDouble(),
            currentStock: i['currentStock'] != null
                ? (i['currentStock'] as num).toDouble() : 0,
            lowStockAlert: i['lowStockAlert'] != null
                ? (i['lowStockAlert'] as num).toDouble() : 10,
          );
          restored++;
        }
      }

      setState(() => _status =
          '✅ Restored $restored new records successfully!');
    } catch (e) {
      setState(() => _status = '❌ Restore failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  border: Border.all(
                      color: _status.startsWith('✅')
                          ? Colors.green.shade200
                          : _status.startsWith('❌')
                              ? Colors.red.shade200
                              : Colors.blue.shade200),
                ),
                child: Text(_status),
              ),

            // Backup section
            const Text('Create Backup',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
                'Export all your customers, items, invoices and payments.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text('Save to Device'),
                  onPressed:
                      _loading ? null : _createLocalBackup,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share / Drive'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600),
                  onPressed: _loading ? null : _shareBackup,
                ),
              ),
            ]),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Local backups list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saved Backups',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBackupList),
              ],
            ),
            const SizedBox(height: 8),

            if (_localBackups.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text('No local backups yet',
                          style:
                              TextStyle(color: Colors.grey))),
                ),
              )
            else
              ..._localBackups.map((file) {
                final name = file.path.split('/').last;
                final stat = file.statSync();
                final size =
                    (stat.size / 1024).toStringAsFixed(1);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                        Icons.backup, color: Colors.green),
                    title: Text(name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text('$size KB'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restore,
                              color: Colors.blue),
                          tooltip: 'Restore',
                          onPressed: () =>
                              _restoreFromFile(file),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share,
                              color: Colors.grey),
                          tooltip: 'Share',
                          onPressed: () async {
                            await Share.shareXFiles(
                                [XFile(file.path)],
                                subject: 'VyapaarX Backup');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 16),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber, size: 18),
                      SizedBox(width: 6),
                      Text('Tip',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                    ]),
                    SizedBox(height: 6),
                    Text(
                      '• Use "Share / Drive" to save backup to Google Drive\n'
                      '• Tap "Restore" to import data from a saved backup\n'
                      '• Take a backup weekly to avoid data loss',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
