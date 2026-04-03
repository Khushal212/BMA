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
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'VyapaarX',
      'customers': customers
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'address': c.address,
                'creditLimit': c.creditLimit,
                'defaultGstPercent': c.defaultGstPercent,
                'createdAt': c.createdAt,
              })
          .toList(),
      'items': items
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'unit': i.unit,
                'defaultRate': i.defaultRate,
                'gstPercent': i.gstPercent,
                'currentStock': i.currentStock,
                'lowStockAlert': i.lowStockAlert,
                'createdAt': i.createdAt,
              })
          .toList(),
      'invoices': invoices
          .map((i) => {
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
              })
          .toList(),
      'invoiceLines': invoiceLines,
      'payments': allPayments,
    };
  }

  Future<void> _createLocalBackup() async {
    setState(() {
      _loading = true;
      _status = 'Creating backup...';
    });
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
    setState(() {
      _loading = true;
      _status = 'Preparing backup...';
    });
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
        subject:
            'VyapaarX Backup - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
        text:
            'VyapaarX data backup. Import this file to restore your data.',
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
    await _doRestore(file);
  }

  Future<void> _doRestore(File file) async {
    setState(() {
      _loading = true;
      _status = 'Restoring...';
    });
    try {
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final db = context.read<AppDatabase>();

      int restored = 0;
      for (final c in (data['customers'] as List)) {
        final existing = await db.getCustomer(c['id']);
        if (existing == null) {
          await db.createCustomer(
            id: c['id'],
            name: c['name'],
            phone: c['phone'],
            address: c['address'],
            creditLimit: (c['creditLimit'] as num).toDouble(),
            defaultGstPercent:
                (c['defaultGstPercent'] as num).toDouble(),
          );
          restored++;
        }
      }
      for (final i in (data['items'] as List)) {
        final existing = await db.getItem(i['id']);
        if (existing == null) {
          await db.createItem(
            id: i['id'],
            name: i['name'],
            unit: i['unit'],
            defaultRate: i['defaultRate'] != null
                ? (i['defaultRate'] as num).toDouble()
                : null,
            gstPercent: (i['gstPercent'] as num).toDouble(),
            currentStock: i['currentStock'] != null
                ? (i['currentStock'] as num).toDouble()
                : 0,
            lowStockAlert: i['lowStockAlert'] != null
                ? (i['lowStockAlert'] as num).toDouble()
                : 10,
          );
          restored++;
        }
      }

      setState(() =>
          _status = '✅ Restored $restored new records successfully!');
    } catch (e) {
      setState(() => _status = '❌ Restore failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Pick a .json backup file from device storage using a simple path input
  Future<void> _uploadAndRestore() async {
    final pathCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📂 Upload Backup File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'First share/save your backup JSON file to your device, '
              'then enter the full file path below.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(
                labelText: 'File path',
                hintText:
                    '/storage/emulated/0/Download/vyapaarx_backup.json',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
            const SizedBox(height: 8),
            // Quick path shortcuts
            const Text('Common locations:',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Downloads',
                      style: TextStyle(fontSize: 11)),
                  onPressed: () => pathCtrl.text =
                      '/storage/emulated/0/Download/',
                ),
                ActionChip(
                  label: const Text('Documents',
                      style: TextStyle(fontSize: 11)),
                  onPressed: () => pathCtrl.text =
                      '/storage/emulated/0/Documents/',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (result != true) return;
    final path = pathCtrl.text.trim();
    if (path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
      setState(
          () => _status = '❌ File not found at path: $path');
      return;
    }
    await _doRestore(file);
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
            // Status banner
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
                child: Row(children: [
                  Icon(
                    _status.startsWith('✅')
                        ? Icons.check_circle
                        : _status.startsWith('❌')
                            ? Icons.error
                            : Icons.info,
                    color: _status.startsWith('✅')
                        ? Colors.green
                        : _status.startsWith('❌')
                            ? Colors.red
                            : Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_status)),
                ]),
              ),

            // ── BACKUP SECTION ─────────────────────────────
            _sectionHeader(
                Icons.backup, 'Create Backup', Colors.green),
            const SizedBox(height: 4),
            const Text(
              'Export all customers, items, invoices and payments.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Big backup buttons
            Row(children: [
              Expanded(
                child: _BigButton(
                  icon: Icons.save_alt,
                  label: 'Save to\nDevice',
                  color: Colors.green,
                  loading: _loading,
                  onPressed: _createLocalBackup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigButton(
                  icon: Icons.share,
                  label: 'Share /\nGoogle Drive',
                  color: Colors.blue,
                  loading: _loading,
                  onPressed: _shareBackup,
                ),
              ),
            ]),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // ── RESTORE SECTION ────────────────────────────
            _sectionHeader(
                Icons.restore, 'Restore Data', Colors.orange),
            const SizedBox(height: 4),
            const Text(
              'Restore from a previously saved backup file.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Big restore/upload button
            SizedBox(
              width: double.infinity,
              child: _BigButton(
                icon: Icons.upload_file,
                label: 'Upload & Restore Backup File',
                color: Colors.orange,
                loading: _loading,
                onPressed: _uploadAndRestore,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // ── LOCAL BACKUPS LIST ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader(
                    Icons.folder, 'Saved Backups', Colors.purple),
                IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBackupList),
              ],
            ),
            const SizedBox(height: 8),

            if (_localBackups.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.backup_outlined,
                            size: 48,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('No local backups yet',
                            style:
                                TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text(
                            'Tap "Save to Device" to create one',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._localBackups.map((file) {
                final name = file.path.split('/').last;
                final stat = file.statSync();
                final size = (stat.size / 1024).toStringAsFixed(1);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.description,
                          color: Colors.green),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text('$size KB',
                        style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Restore button
                        TextButton.icon(
                          icon: const Icon(Icons.restore,
                              size: 16, color: Colors.orange),
                          label: const Text('Restore',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12)),
                          onPressed: () =>
                              _restoreFromFile(file),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets
                                  .symmetric(horizontal: 8)),
                        ),
                        // Share button
                        IconButton(
                          icon: const Icon(Icons.share,
                              size: 18, color: Colors.grey),
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

            // Tip card
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lightbulb_outline,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      const Text('Tips',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      '• Use "Share / Google Drive" to save backup to Google Drive\n'
                      '• Use "Save to Device" for a local backup\n'
                      '• Use "Upload & Restore" to restore from any saved file\n'
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

  Widget _sectionHeader(IconData icon, String title, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color)),
      ]);
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      );
}
