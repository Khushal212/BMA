import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';
import '../main.dart';

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
    'kg', 'gram', 'crate', 'bunch', 'box', 'bag', 'piece', 'dozen', 'litre'
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
    final list = await context.read<AppDatabase>().getAllItems();
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
    return _items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  String? _validateItemName(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return l.nameRequired;
    if (v.trim().length < 2) return l.nameTooShort;
    if (v.trim().length > 50) return l.nameTooLong;
    return null;
  }

  String? _validateRate(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return null; // optional
    final rate = double.tryParse(v.trim());
    if (rate == null) return l.invalidNumber;
    if (rate < 0) return l.cannotBeNegative;
    return null;
  }

  String? _validateGst(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return l.required;
    final gst = double.tryParse(v.trim());
    if (gst == null) return l.invalidNumber;
    if (gst < 0) return l.cannotBeNegative;
    if (gst > 28) return '${l.cannotExceed} 28%';
    return null;
  }

  Future<void> _showAddEditDialog({Item? existing}) async {
    final l = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rateCtrl = TextEditingController(
        text: existing?.defaultRate?.toStringAsFixed(2) ?? '');
    final gstCtrl = TextEditingController(
        text: (existing?.gstPercent ?? 0).toStringAsFixed(0));
    String unit = existing?.unit ?? 'kg';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? l.addItem : l.editItem),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.itemName,
                    hintText: l.itemNameHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.inventory_2),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: _validateItemName,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: InputDecoration(
                    labelText: l.unit,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.scale),
                  ),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setDlg(() => unit = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rateCtrl,
                  decoration: InputDecoration(
                    labelText: l.defaultRate,
                    hintText: l.defaultRateHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: _validateRate,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gstCtrl,
                  decoration: InputDecoration(
                    labelText: l.gstPercent,
                    hintText: l.gstPercentHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.percent),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,1}')),
                  ],
                  validator: _validateGst,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
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
      await db.updateItem(ItemsCompanion(
        id: Value(existing.id),
        name: Value(nameCtrl.text.trim()),
        unit: Value(unit),
        defaultRate: Value(rate),
        gstPercent: Value(gst),
      ));
    }
    _loadItems();
  }

  Future<void> _deleteItem(Item item) async {
    final l = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteItem),
        content: Text('"${item.name}"? ${l.deleteItemConfirm}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.items),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${_items.length}',
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l.searchItem,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _items.isEmpty
                              ? l.noItemsYet
                              : 'No results for "$_query"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = _filtered[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                item.name[0].toUpperCase(),
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${item.unit}  •  ${l.gstPercent}: ${item.gstPercent.toStringAsFixed(0)}%'),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.defaultRate != null
                                      ? 'Rs.${item.defaultRate!.toStringAsFixed(0)}'
                                      : l.noRate,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: item.defaultRate != null
                                          ? Colors.green.shade700
                                          : Colors.grey),
                                ),
                                Text(l.default_,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            onTap: () => showModalBottomSheet(
                              context: ctx,
                              builder: (_) => SafeArea(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: Text(l.edit),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _showAddEditDialog(existing: item);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete,
                                            color: Colors.red),
                                        title: Text(l.delete,
                                            style: const TextStyle(
                                                color: Colors.red)),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _deleteItem(item);
                                        },
                                      ),
                                    ]),
                              ),
                            ),
                            onLongPress: () =>
                                _showAddEditDialog(existing: item),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
