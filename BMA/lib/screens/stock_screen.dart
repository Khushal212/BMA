import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Item> _items = [];
  bool _loading = true;
  bool _showLowOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppDatabase>();
    final list = await db.getAllItems();
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  List<Item> get _displayed => _showLowOnly
      ? _items.where((i) => i.currentStock <= i.lowStockAlert).toList()
      : _items;

  Future<void> _addStockDialog(Item item) async {
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = 'PURCHASE';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Update Stock — ${item.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.currentStock <= item.lowStockAlert
                    ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current Stock:'),
                  Text(
                    '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.currentStock <= item.lowStockAlert
                          ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                labelText: 'Movement Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'PURCHASE', child: Text('➕ Add Stock (Purchase)')),
                DropdownMenuItem(value: 'ADJUSTMENT', child: Text('🔧 Adjustment')),
                DropdownMenuItem(value: 'WASTAGE', child: Text('❌ Wastage / Loss')),
              ],
              onChanged: (v) => setDlg(() => type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: qtyCtrl,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: const OutlineInputBorder(),
                suffixText: item.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (qtyCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final qty = double.parse(qtyCtrl.text.trim());
    final finalQty = (type == 'WASTAGE') ? -qty : qty;

    await context.read<AppDatabase>().addStock(
      itemId: item.id,
      quantity: finalQty,
      type: type,
      notes: notesCtrl.text.trim().isEmpty
          ? null : notesCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock updated for ${item.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
    _load();
  }

  Future<void> _updateAlertDialog(Item item) async {
    final alertCtrl = TextEditingController(
        text: item.lowStockAlert.toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Low Stock Alert — ${item.name}'),
        content: TextFormField(
          controller: alertCtrl,
          decoration: InputDecoration(
            labelText: 'Alert when stock falls below',
            border: const OutlineInputBorder(),
            suffixText: item.unit,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true) return;
    await context.read<AppDatabase>().updateItem(
      item.copyWith(
        lowStockAlert: double.parse(alertCtrl.text.trim()),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final lowCount =
        _items.where((i) => i.currentStock <= i.lowStockAlert).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // Low stock banner
        if (lowCount > 0)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.warning, color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                '$lowCount item(s) running low on stock!',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),

        // Filter toggle
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(children: [
            const Text('Show low stock only'),
            const Spacer(),
            Switch(
              value: _showLowOnly,
              activeColor: Colors.red,
              onChanged: (v) => setState(() => _showLowOnly = v),
            ),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _displayed.isEmpty
                  ? Center(
                      child: Text(
                        _showLowOnly
                            ? 'No low stock items 👍'
                            : 'No items found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _displayed.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _displayed[i];
                          final isLow =
                              item.currentStock <= item.lowStockAlert;
                          final pct = item.lowStockAlert > 0
                              ? (item.currentStock /
                                      (item.lowStockAlert * 3))
                                  .clamp(0.0, 1.0)
                              : 1.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    CircleAvatar(
                                      backgroundColor: isLow
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      radius: 20,
                                      child: Text(
                                        item.name[0].toUpperCase(),
                                        style: TextStyle(
                                          color: isLow
                                              ? Colors.red
                                              : Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 15)),
                                          Text(
                                            isLow
                                                ? '⚠️ Low Stock!'
                                                : 'In Stock',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLow
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isLow
                                                ? Colors.red
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Alert: ${item.lowStockAlert.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  // Stock bar
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct.toDouble(),
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      color: isLow
                                          ? Colors.red
                                          : Colors.green,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Update Stock'),
                                        onPressed: () =>
                                            _addStockDialog(item),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets
                                              .symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.notifications_outlined,
                                          size: 20),
                                      tooltip: 'Set Alert Level',
                                      onPressed: () =>
                                          _updateAlertDialog(item),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
