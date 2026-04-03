import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerAnim;
  late Animation<double> _cardsAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700));
    _cardsCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));

    _headerAnim = CurvedAnimation(
        parent: _headerCtrl, curve: Curves.easeOut);
    _cardsAnim = CurvedAnimation(
        parent: _cardsCtrl, curve: Curves.easeOut);

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300),
        () => _cardsCtrl.forward());
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final fmt = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () async => setState(() {}),
        child: CustomScrollView(
          slivers: [
            // ── Animated Header ──────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.navy,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu,
                      color: AppColors.white),
                  onPressed: () =>
                      Scaffold.of(ctx).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh,
                      color: AppColors.white),
                  onPressed: () => setState(() {}),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: AnimatedBuilder(
                  animation: _headerAnim,
                  builder: (_, __) => Opacity(
                    opacity: _headerAnim.value,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.navyDark,
                            AppColors.navy,
                            AppColors.navyLight,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              16, 50, 16, 16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: TextStyle(
                                  color: Colors.white
                                      .withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'VyapaarX',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fmt.format(now),
                                style: TextStyle(
                                  color: AppColors.gold
                                      .withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _cardsAnim,
                builder: (_, child) => Opacity(
                  opacity: _cardsAnim.value,
                  child: Transform.translate(
                    offset:
                        Offset(0, 20 * (1 - _cardsAnim.value)),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ── Stat Cards ────────────────────────
                      Row(children: [
                        Expanded(
                          child: FutureBuilder<double>(
                            future: db.getTodaysSalesTotal(),
                            builder: (ctx, snap) =>
                                _AnimatedStatCard(
                              label: "Today's Sales",
                              value:
                                  'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                              icon: Icons.trending_up,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.navy,
                                  AppColors.navyLight
                                ],
                              ),
                              delay: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FutureBuilder<double>(
                            future: db.getTotalOutstanding(),
                            builder: (ctx, snap) =>
                                _AnimatedStatCard(
                              label: 'Outstanding',
                              value:
                                  'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                              icon: Icons.account_balance_wallet,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withOpacity(0.8),
                                  AppColors.gold,
                                ],
                              ),
                              delay: 100,
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── Quick Actions ─────────────────────
                      const Text('Quick Actions',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.navy)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _QuickAction(
                            icon: Icons.receipt_long,
                            label: 'New\nInvoice',
                            color: AppColors.navy,
                            onTap: () => MainNavigation.jumpTo(
                                context, 3),
                          ),
                          _QuickAction(
                            icon: Icons.people,
                            label: 'Customers',
                            color: AppColors.accent,
                            onTap: () => MainNavigation.jumpTo(
                                context, 1),
                          ),
                          _QuickAction(
                            icon: Icons.inventory_2,
                            label: 'Items',
                            color: AppColors.gold,
                            onTap: () => MainNavigation.jumpTo(
                                context, 2),
                          ),
                          _QuickAction(
                            icon: Icons.history,
                            label: 'History',
                            color: Colors.purple,
                            onTap: () => MainNavigation.jumpTo(
                                context, 4),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Daily Sales Report ─────────────────
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Daily Sales Report',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.navy)),
                          TextButton.icon(
                            icon: const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: AppColors.navy),
                            label: Text(
                                fmt.format(_selectedDate),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.navy)),
                            onPressed: () async {
                              final picked =
                                  await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (ctx, child) =>
                                    Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme:
                                        const ColorScheme.light(
                                      primary: AppColors.navy,
                                      onPrimary: AppColors.white,
                                    ),
                                  ),
                                  child: child!,
                                ),
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
                                child:
                                    CircularProgressIndicator(
                                        color: AppColors.navy));
                          }
                          final s = snap.data!;
                          return Column(children: [
                            // Mini summary
                            Row(children: [
                              Expanded(
                                  child: _MiniCard(
                                      'Total Sales',
                                      'Rs.${s.totalSales.toStringAsFixed(0)}',
                                      AppColors.navy)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniCard(
                                      'Collected',
                                      'Rs.${s.collected.toStringAsFixed(0)}',
                                      AppColors.accent)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _MiniCard(
                                      'Pending',
                                      'Rs.${s.pending.toStringAsFixed(0)}',
                                      AppColors.danger)),
                            ]),
                            const SizedBox(height: 12),
                            if (s.invoices.isEmpty)
                              Card(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(20),
                                  child: Center(
                                    child: Column(children: [
                                      Icon(
                                          Icons
                                              .receipt_long_outlined,
                                          size: 40,
                                          color: Colors
                                              .grey.shade300),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No sales on ${fmt.format(_selectedDate)}',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                                    ]),
                                  ),
                                ),
                              )
                            else
                              ...s.invoices.map((inv) => Card(
                                    margin:
                                        const EdgeInsets.only(
                                            bottom: 8),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(
                                              12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                  inv.customerName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      fontSize:
                                                          14,
                                                      color: AppColors
                                                          .navy)),
                                              Text(
                                                  inv.invoiceNo,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey)),
                                            ],
                                          ),
                                          const SizedBox(
                                              height: 6),
                                          ...inv.lines.map(
                                              (l) => Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical:
                                                            2),
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
                                          const Divider(
                                              height: 12),
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
                                                              .bold,
                                                      color: AppColors
                                                          .navy)),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                                decoration:
                                                    BoxDecoration(
                                                  color: inv.balanceAmount ==
                                                          0
                                                      ? AppColors
                                                          .success
                                                          .withOpacity(
                                                              0.15)
                                                      : AppColors
                                                          .danger
                                                          .withOpacity(
                                                              0.15),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              8),
                                                ),
                                                child: Text(
                                                  inv.balanceAmount ==
                                                          0
                                                      ? 'PAID'
                                                      : 'Due: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: inv.balanceAmount ==
                                                            0
                                                        ? AppColors
                                                            .success
                                                        : AppColors
                                                            .danger,
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                  ),
                                                ),
                                              ),
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

                      // ── Credit Alerts ──────────────────────
                      FutureBuilder<List<Customer>>(
                        future:
                            db.getExceededCreditLimitCustomers(),
                        builder: (ctx, snap) {
                          final exceeded = snap.data ?? [];
                          if (exceeded.isEmpty)
                            return const SizedBox();
                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.warning_amber,
                                    color: AppColors.danger,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${exceeded.length} Customer(s) Exceeded Credit Limit',
                                  style: const TextStyle(
                                      color: AppColors.danger,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              ...exceeded.map((c) =>
                                  FutureBuilder<double>(
                                    future: db
                                        .getCustomerOutstanding(
                                            c.id),
                                    builder: (ctx, snap) {
                                      final out =
                                          snap.data ?? 0;
                                      return Card(
                                        color: AppColors.danger
                                            .withOpacity(0.08),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(12),
                                          side: BorderSide(
                                              color: AppColors
                                                  .danger
                                                  .withOpacity(
                                                      0.3)),
                                        ),
                                        margin:
                                            const EdgeInsets.only(
                                                bottom: 6),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets
                                                  .all(12),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Row(children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor:
                                                      AppColors
                                                          .danger
                                                          .withOpacity(
                                                              0.15),
                                                  child: Text(
                                                    c.name[0]
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                        color:
                                                            AppColors.danger,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: 10),
                                                Text(c.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ]),
                                              Text(
                                                'Rs.${out.toStringAsFixed(0)} / Rs.${c.creditLimit.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                    color:
                                                        AppColors.danger,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated Stat Card ─────────────────────────────────────────
class _AnimatedStatCard extends StatefulWidget {
  final String label, value;
  final IconData icon;
  final Gradient gradient;
  final int delay;

  const _AnimatedStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.delay,
  });

  @override
  State<_AnimatedStatCard> createState() =>
      _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(
        parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(Duration(milliseconds: widget.delay),
        () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon,
                  color: Colors.white70, size: 20),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(widget.value,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.9,
        upperBound: 1.0)
      ..value = 1.0;
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(
          scale: _scale,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: widget.color.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon,
                  size: 26, color: widget.color),
            ),
            const SizedBox(height: 6),
            Text(widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
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
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.2))),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8)),
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
