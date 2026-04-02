import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary cards ──────────────────────────────
            Row(children: [
              Expanded(
                child: FutureBuilder<double>(
                  future: db.getTodaysSalesTotal(),
                  builder: (ctx, snap) => _StatCard(
                    label: "Today's Sales",
                    value:
                        'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                    color: Colors.green.shade600,
                    icon: Icons.trending_up,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<double>(
                  future: db.getTotalOutstanding(),
                  builder: (ctx, snap) => _StatCard(
                    label: 'Outstanding',
                    value:
                        'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                    color: Colors.blue.shade600,
                    icon: Icons.account_balance_wallet,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Quick Actions ──────────────────────────────
            const Text('Quick Actions',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: Icons.receipt_long,
                  label: 'New Invoice',
                  color: Colors.green,
                  onTap: () =>
                      MainNavigation.jumpTo(context, 3),
                ),
                _QuickAction(
                  icon: Icons.people,
                  label: 'Customers',
                  color: Colors.blue,
                  onTap: () =>
                      MainNavigation.jumpTo(context, 1),
                ),
                _QuickAction(
                  icon: Icons.inventory_2,
                  label: 'Items',
                  color: Colors.orange,
                  onTap: () =>
                      MainNavigation.jumpTo(context, 2),
                ),
                _QuickAction(
                  icon: Icons.history,
                  label: 'History',
                  color: Colors.purple,
                  onTap: () =>
                      MainNavigation.jumpTo(context, 4),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Daily Sales Report ─────────────────────────
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daily Sales Report',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today,
                      size: 16),
                  label: Text(fmt.format(_selectedDate),
                      style: const TextStyle(fontSize: 13)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(
                          () => _selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<DailySummary>(
              future: db.getDailySummary(_selectedDate),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final s = snap.data!;
                return Column(children: [
                  // Summary row
                  Row(children: [
                    Expanded(
                        child: _MiniCard(
                            'Total Sales',
                            'Rs.${s.totalSales.toStringAsFixed(0)}',
                            Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MiniCard(
                            'Collected',
                            'Rs.${s.collected.toStringAsFixed(0)}',
                            Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MiniCard(
                            'Pending',
                            'Rs.${s.pending.toStringAsFixed(0)}',
                            Colors.red)),
                  ]),
                  const SizedBox(height: 12),

                  if (s.invoices.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No sales on ${fmt.format(_selectedDate)}',
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    ...s.invoices.map((inv) => Card(
                          margin: const EdgeInsets.only(
                              bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(inv.customerName,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize: 14)),
                                    Text(inv.invoiceNo,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...inv.lines.map((l) => Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              vertical: 2),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                              '${l.itemNameSnapshot} × ${l.qty} ${l.unit}',
                                              style: const TextStyle(
                                                  fontSize:
                                                      13)),
                                          Text(
                                              'Rs.${l.lineTotal.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  fontSize:
                                                      13)),
                                        ],
                                      ),
                                    )),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    Text(
                                        'Total: Rs.${inv.total.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold)),
                                    Row(children: [
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 3),
                                        decoration: BoxDecoration(
                                            color: inv.balanceAmount ==
                                                    0
                                                ? Colors.green
                                                    .shade100
                                                : Colors.red
                                                    .shade100,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        8)),
                                        child: Text(
                                          inv.balanceAmount == 0
                                              ? 'PAID'
                                              : 'Pending: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: inv.balanceAmount ==
                                                      0
                                                  ? Colors.green
                                                      .shade700
                                                  : Colors.red
                                                      .shade700,
                                              fontWeight:
                                                  FontWeight
                                                      .bold),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                ]);
              },
            ),

            const SizedBox(height: 16),

            // ── Credit limit alerts ────────────────────────
            FutureBuilder<List<Customer>>(
              future: db.getExceededCreditLimitCustomers(),
              builder: (ctx, snap) {
                final exceeded = snap.data ?? [];
                if (exceeded.isEmpty) return const SizedBox();
                return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.warning,
                            color: Colors.red.shade600,
                            size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${exceeded.length} Customer(s) Exceeded Credit Limit',
                          style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ...exceeded.map((c) =>
                          FutureBuilder<double>(
                            future:
                                db.getCustomerOutstanding(c.id),
                            builder: (ctx, snap) {
                              final out = snap.data ?? 0;
                              return Card(
                                color: Colors.red.shade50,
                                margin: const EdgeInsets.only(
                                    bottom: 6),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                    children: [
                                      Text(c.name,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .bold)),
                                      Text(
                                        'Rs.${out.toStringAsFixed(0)} / Rs.${c.creditLimit.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            color: Colors
                                                .red.shade700,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
                    ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withOpacity(0.8),
              color,
            ]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ]),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _MiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withOpacity(0.3))),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color.withOpacity(0.8)),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center),
        ]),
      );
}
