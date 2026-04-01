import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({Key? key}) : super(key: key);

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Item> _items = [];
  bool _loading = true;

  final List<String> _units = [
    'kg', 'crate', 'bunch', 'box', 'bag', 'piece'
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final list =
        await context.read<AppDatabase>().getAllItems();
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  List<Item> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
            (i) => i.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _showAddEditDialog({Item? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final rateCtrl = TextEditingController(
        text: existing?.defaultRate
                ?.toStringAsFixed(0) ??
            '');
    final gstCtrl = TextEditingController(
        text:
            (existing?.gstPercent ?? 0).toStringAsFixed(0));
    String unit = existing?.unit ?? 'kg';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          StatefulBuilder(builder: (ctx, setDlg) {
        return AlertDialog(
          title: Text(
              existing == null ? 'Add Item' : 'Edit Item'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unit,
                    decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder()),
                    items: _units
                        .map((u) => DropdownMenuItem(
                            value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) =>
                        setDlg(() => unit = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rateCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Default Rate (Rs.)',
                        hintText: 'Optional',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null &&
                          v.isNotEmpty &&
                          double.tryParse(v) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: gstCtrl,
                    decoration: const InputDecoration(
                        labelText: 'GST %',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        double.tryParse(v ?? '') == null
                            ? 'Invalid'
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Save')),
          ],
        );
      }),
    );

    if (result != true) return;

    final db = context.read<AppDatabase>();
    final rate = rateCtrl.text.trim().isEmpty
        ? null
        : double.parse(rateCtrl.text.trim());
    final gst = double.parse(gstCtrl.text.trim());

    if (existing == null) {
      await db.createItem(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        unit: unit,
        defaultRate: rate,
        gstPercent: gst,
      );
    } else {
      await db.updateItem(existing.copyWith(
        name: nameCtrl.text.trim(),
        unit: unit,
        defaultRate: Value(rate),
        gstPercent: gst,
      ));
    }
    _loadItems();
  }

  Future<void> _deleteItem(Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await context.read<AppDatabase>().deleteItem(item.id);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Items'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search item...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _items.isEmpty
                              ? 'No items yet.\nTap + to add one.'
                              : 'No results for "$_query"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = _filtered[idx];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors
                                    .green.shade100,
                                child: Text(
                                  item.name[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                      color: Colors
                                          .green.shade700,
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                              ),
                              title: Text(item.name,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              subtitle: Text(
                                  '${item.unit}  •  GST: ${item.gstPercent.toStringAsFixed(0)}%'),
                              trailing: Text(
                                item.defaultRate != null
                                    ? 'Rs.${item.defaultRate!.toStringAsFixed(0)}'
                                    : 'No rate',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: item.defaultRate !=
                                            null
                                        ? Colors
                                            .green.shade700
                                        : Colors.grey),
                              ),
                              onTap: () =>
                                  showModalBottomSheet(
                                context: ctx,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                            Icons.edit),
                                        title: const Text(
                                            'Edit'),
                                        onTap: () {
                                          Navigator.pop(
                                              ctx);
                                          _showAddEditDialog(
                                              existing:
                                                  item);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                            Icons.delete,
                                            color:
                                                Colors.red),
                                        title: const Text(
                                            'Delete',
                                            style: TextStyle(
                                                color: Colors
                                                    .red)),
                                        onTap: () {
                                          Navigator.pop(
                                              ctx);
                                          _deleteItem(item);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              onLongPress: () =>
                                  _showAddEditDialog(
                                      existing: item),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
