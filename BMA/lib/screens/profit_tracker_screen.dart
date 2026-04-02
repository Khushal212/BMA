import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/app_database.dart';

class ProfitTrackerScreen extends StatefulWidget {
  const ProfitTrackerScreen({Key? key}) : super(key: key);
  @override
  State<ProfitTrackerScreen> createState() =>
      _ProfitTrackerScreenState();
}

class _ItemProfit {
  final Item item;
  final double totalQtySold;
  final double totalRevenue;
  final double costPerUnit;
  final double totalCost;
  double get grossProfit => totalRevenue - totalCost;
  double get marginPct =>
      totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;

  _ItemProfit({
    required this.item,
    required this.totalQtySold,
    required this.totalRevenue,
    required this.costPerUnit,
    required this.totalCost,
  });
}

class _ProfitTrackerScreenState
    extends State<ProfitTrackerScreen> {
  List<_ItemProfit> _profits = [];
  bool _loading = true;
  DateTime _from = DateTime.now()
      .subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  // Cost prices stored in settings as 'cost_ITEMID'
  Map<String, double> _costPrices = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final items = await db.getAllItems();
    final allInvoices = await db.getAllInvoices();

    // Load saved cost prices
    final costs = <String, double>{};
    for (final item in items) {
      final saved =
          await db.getSetting('cost_${item.id}');
      costs[item.id] =
          saved != null ? double.parse(saved) : 0;
    }

    final start = DateTime(_from.year, _from.month, _from.day)
        .millisecondsSinceEpoch;
    final end =
        DateTime(_to.year, _to.month, _to.day, 23, 59, 59)
            .millisecondsSinceEpoch;

    final periodInvoices = allInvoices.where((i) =>
        i.invoiceDate >= start && i.invoiceDate <= end);

    // Aggregate by item
    final itemSales = <String, Map<String, double>>{};
    for (final inv in periodInvoices) {
      final lines = await db.getInvoiceLines(inv.id);
      for (final l in lines) {
        itemSales.putIfAbsent(l.itemId,
            () => {'qty': 0, 'revenue': 0});
        itemSales[l.itemId]!['qty'] =
            (itemSales[l.itemId]!['qty'] ?? 0) + l.qty;
        itemSales[l.itemId]!['revenue'] =
            (itemSales[l.itemId]!['revenue'] ?? 0) +
                l.lineSubtotal;
      }
    }

    final profits = <_ItemProfit>[];
    for (final item in items) {
      if (!itemSales.containsKey(item.id)) continue;
      final qty = itemSales[item.id]!['qty'] ?? 0;
      final revenue = itemSales[item.id]!['revenue'] ?? 0;
      final cost = costs[item.id] ?? 0;
      profits.add(_ItemProfit(
        item: item,
        totalQtySold: qty,
        totalRevenue: revenue,
        costPerUnit: cost,
        totalCost: cost * qty,
      ));
    }

    profits.sort(
        (a, b) => b.grossProfit.compareTo(a.grossProfit));

    if (mounted) {
      setState(() {
        _profits = profits;
        _costPrices = costs;
        _loading = false;
      });
    }
  }

  Future<void> _editCostPrice(Item item) async {
    final ctrl = TextEditingController(
        text: (_costPrices[item.id] ?? 0).toStringAsFixed(2));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cost Price — ${item.name}'),
        content: TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText:
                'Your buying price per ${item.unit}',
            border: const OutlineInputBorder(),
            prefixText: 'Rs. ',
            helperText:
                'Default selling: Rs.${item.defaultRate?.toStringAsFixed(0) ?? "N/A"}',
          ),
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,2}')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != true) return;
    final cost = double.tryParse(ctrl.text.trim()) ?? 0;
    await context
        .read<AppDatabase>()
        .saveSetting('cost_${item.id}', cost.toString());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM');
    final totalRevenue =
        _profits.fold(0.0, (s, p) => s + p.totalRevenue);
    final totalCost =
        _profits.fold(0.0, (s, p) => s + p.totalCost);
    final totalProfit = totalRevenue - totalCost;
    final overallMargin = totalRevenue > 0
        ? (totalProfit / totalRevenue) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Tracker'),
        centerTitle: true,
      ),
      body: Column(children: [
        // Date range selector
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                    '${fmt.format(_from)} — ${fmt.format(_to)}'),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(
                        start: _from, end: _to),
                  );
                  if (range != null) {
                    setState(() {
                      _from = range.start;
                      _to = range.end;
                    });
                    _load();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _load),
          ]),
        ),

        // Overall summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            color: totalProfit >= 0
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Total Revenue',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                      Text(
                          'Rs.${totalRevenue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Total Cost',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                      Text(
                          'Rs.${totalCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text('Gross Profit',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                      Text(
                        'Rs.${totalProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: totalProfit >= 0
                              ? Colors.green.shade700
                              : Colors.red,
                        ),
                      ),
                      Text(
                        '${overallMargin.toStringAsFixed(1)}% margin',
                        style: TextStyle(
                            fontSize: 11,
                            color: totalProfit >= 0
                                ? Colors.green
                                : Colors.red),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Item-wise Profit',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            const Text('Tap to set cost price',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : _profits.isEmpty
                  ? const Center(
                      child: Text(
                          'No sales in selected period',
                          style:
                              TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      itemCount: _profits.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final p = _profits[i];
                        final hasCost = p.costPerUnit > 0;
                        final isProfit = p.grossProfit >= 0;

                        return Card(
                          child: InkWell(
                            onTap: () =>
                                _editCostPrice(p.item),
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(12),
                              child: Column(children: [
                                Row(children: [
                                  CircleAvatar(
                                    backgroundColor: hasCost
                                        ? (isProfit
                                            ? Colors
                                                .green.shade100
                                            : Colors
                                                .red.shade100)
                                        : Colors.grey.shade100,
                                    child: Text(
                                      p.item.name[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: hasCost
                                            ? (isProfit
                                                ? Colors.green
                                                : Colors.red)
                                            : Colors.grey,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(p.item.name,
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .w600)),
                                        Text(
                                          'Sold: ${p.totalQtySold.toStringAsFixed(1)} ${p.item.unit}  •  Revenue: Rs.${p.totalRevenue.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (hasCost)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .end,
                                      children: [
                                        Text(
                                          'Rs.${p.grossProfit.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 16,
                                            color: isProfit
                                                ? Colors
                                                    .green.shade700
                                                : Colors.red,
                                          ),
                                        ),
                                        Text(
                                          '${p.marginPct.toStringAsFixed(1)}% margin',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isProfit
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors
                                              .orange.shade50,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(6),
                                          border: Border.all(
                                              color: Colors
                                                  .orange.shade200)),
                                      child: const Text(
                                        'Set cost',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Colors.orange),
                                      ),
                                    ),
                                ]),
                                if (hasCost) ...[
                                  const SizedBox(height: 8),
                                  // Profit bar
                                  Row(children: [
                                    Expanded(
                                      flex:
                                          p.totalCost.toInt(),
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors
                                              .red.shade300,
                                          borderRadius:
                                              const BorderRadius
                                                  .horizontal(
                                                  left: Radius
                                                      .circular(
                                                          4)),
                                        ),
                                      ),
                                    ),
                                    if (p.grossProfit > 0)
                                      Expanded(
                                        flex: p.grossProfit
                                            .toInt()
                                            .abs(),
                                        child: Container(
                                          height: 6,
                                          decoration:
                                              BoxDecoration(
                                            color: Colors
                                                .green.shade400,
                                            borderRadius:
                                                const BorderRadius
                                                    .horizontal(
                                                    right: Radius
                                                        .circular(
                                                            4)),
                                          ),
                                        ),
                                      ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(
                                        'Cost: Rs.${p.costPerUnit.toStringAsFixed(0)}/${p.item.unit}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey),
                                      ),
                                      Text(
                                        'Sell: Rs.${(p.totalRevenue / p.totalQtySold).toStringAsFixed(0)}/${p.item.unit} avg',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
