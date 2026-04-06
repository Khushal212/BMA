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
  late AnimationController _headerCtrl, _cardsCtrl, _greetingCtrl;
  late Animation<double> _headerAnim, _cardsAnim, _greetingFade;
  late Animation<Offset> _greetingSlide;

  static const _morningColors   = [Color(0xFF0D1B2A), Color(0xFF1B3A5C), Color(0xFFE8724A)];
  static const _afternoonColors = [Color(0xFF1B2A4A), Color(0xFF1E5DB0), Color(0xFF4A90D9)];
  static const _eveningColors   = [Color(0xFF0A0A1A), Color(0xFF2A1040), Color(0xFF6D3570)];
  static const _nightColors     = [Color(0xFF050C1E), Color(0xFF0E1F45), Color(0xFF1B2A4A)];

  List<Color> get _skyColors {
    final h = DateTime.now().hour;
    if (h >= 6  && h < 12) return _morningColors;
    if (h >= 12 && h < 17) return _afternoonColors;
    if (h >= 17 && h < 21) return _eveningColors;
    return _nightColors;
  }

  bool get _isNight   => DateTime.now().hour >= 21 || DateTime.now().hour < 6;
  bool get _isEvening => DateTime.now().hour >= 17 && DateTime.now().hour < 21;
  bool get _isMorning => DateTime.now().hour >= 6  && DateTime.now().hour < 12;

  @override
  void initState() {
    super.initState();
    _headerCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cardsCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _greetingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _headerAnim    = CurvedAnimation(parent: _headerCtrl,   curve: Curves.easeOut);
    _cardsAnim     = CurvedAnimation(parent: _cardsCtrl,    curve: Curves.easeOut);
    _greetingFade  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _greetingCtrl, curve: Curves.easeOut));
    _greetingSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _greetingCtrl, curve: Curves.easeOutCubic));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200),
        () { if (mounted) _greetingCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _cardsCtrl.forward(); });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    _greetingCtrl.dispose();
    super.dispose();
  }

  Widget _buildStars() {
    if (!_isNight) return const SizedBox.shrink();
    return Positioned.fill(child: CustomPaint(painter: _StarPainter()));
  }

  Widget _buildCelestialBody() {
    if (_isNight) {
      return Positioned(top: 18, right: 60, child: _MoonWidget());
    }
    if (_isEvening) {
      return Positioned(bottom: -20, right: 80,
          child: _SunWidget(size: 70, opacity: 0.55, color: const Color(0xFFFF7B3A)));
    }
    if (_isMorning) {
      return Positioned(top: 10, left: 80,
          child: _SunWidget(size: 50, opacity: 0.65, color: const Color(0xFFFFDE88)));
    }
    return Positioned(top: 10, right: 80,
        child: _SunWidget(size: 55, opacity: 0.6, color: const Color(0xFFFFE44A)));
  }

  // ─────────────────────────────────────────────────────────────
  // IMPORTANT: No Scaffold here — returns CustomScrollView only.
  // The Scaffold (and drawer) lives in MainNavigation in main.dart.
  // Menu button uses MainNavigation.openDrawer(context) to reach it.
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final db  = context.read<AppDatabase>();
    final fmt = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final l   = context.l10n;

    final greeting = now.hour < 12
        ? l.goodMorning
        : now.hour < 17
            ? l.goodAfternoon
            : l.goodEvening;

    final colors = _skyColors;

    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () async => setState(() {}),
      child: CustomScrollView(
        slivers: [

          // ── Sky header ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: colors[0],
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: AppColors.white),
              // Calls openDrawer() on _MainNavigationState
              // which holds the GlobalKey<ScaffoldState>
              onPressed: () => MainNavigation.openDrawer(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.white),
                onPressed: () => setState(() {}),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _headerAnim,
                builder: (_, __) => Opacity(
                  opacity: _headerAnim.value,
                  child: Stack(children: [
                    // Sky gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                    ),
                    _buildStars(),
                    _buildCelestialBody(),
                    if (!_isNight) ...[
                      Positioned(top: 40, left: 30,
                          child: _CloudWidget(
                              opacity: _isEvening ? 0.15 : 0.18,
                              scale: 1.0)),
                      Positioned(top: 25, right: 40,
                          child: _CloudWidget(
                              opacity: _isEvening ? 0.12 : 0.14,
                              scale: 0.7)),
                    ],
                    // Greeting text
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FadeTransition(
                              opacity: _greetingFade,
                              child: SlideTransition(
                                position: _greetingSlide,
                                child: Row(children: [
                                  _TimeIcon(hour: now.hour),
                                  const SizedBox(width: 8),
                                  Text(greeting,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.3)),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FadeTransition(
                              opacity: _greetingFade,
                              child: SlideTransition(
                                position: _greetingSlide,
                                child: Text(l.appTitle,
                                    style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FadeTransition(
                              opacity: _greetingFade,
                              child: Text(fmt.format(now),
                                  style: TextStyle(
                                      color: AppColors.gold.withOpacity(0.95),
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // ── Cards & content ─────────────────────────────
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _cardsAnim,
              builder: (_, child) => Opacity(
                opacity: _cardsAnim.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _cardsAnim.value)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Stat cards
                    Row(children: [
                      Expanded(child: FutureBuilder<double>(
                        future: db.getTodaysSalesTotal(),
                        builder: (ctx, snap) => _AnimatedStatCard(
                          label: l.todaysSales,
                          value: 'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                          icon: Icons.trending_up,
                          gradient: const LinearGradient(
                              colors: [AppColors.navy, AppColors.navyLight]),
                          delay: 0,
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: FutureBuilder<double>(
                        future: db.getTotalOutstanding(),
                        builder: (ctx, snap) => _AnimatedStatCard(
                          label: l.totalOutstanding,
                          value: 'Rs.${(snap.data ?? 0).toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet,
                          gradient: LinearGradient(colors: [
                            AppColors.gold.withOpacity(0.8),
                            AppColors.gold,
                          ]),
                          delay: 100,
                        ),
                      )),
                    ]),

                    const SizedBox(height: 20),

                    // Quick actions
                    Text(l.quickActions,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.navy)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickAction(
                          icon: Icons.receipt_long,
                          label: l.newInvoice,
                          color: AppColors.navy,
                          onTap: () => MainNavigation.jumpTo(context, 3),
                        ),
                        _QuickAction(
                          icon: Icons.people,
                          label: l.customers,
                          color: AppColors.accent,
                          onTap: () => MainNavigation.jumpTo(context, 1),
                        ),
                        _QuickAction(
                          icon: Icons.inventory_2,
                          label: l.items,
                          color: AppColors.gold,
                          onTap: () => MainNavigation.jumpTo(context, 2),
                        ),
                        _QuickAction(
                          icon: Icons.history,
                          label: l.history,
                          color: Colors.purple,
                          onTap: () => MainNavigation.jumpTo(context, 4),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Daily sales report
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l.dailySalesReport,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.navy)),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today,
                              size: 14, color: AppColors.navy),
                          label: Text(fmt.format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.navy)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.navy,
                                    onPrimary: AppColors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
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
                              child: CircularProgressIndicator(
                                  color: AppColors.navy));
                        }
                        final s = snap.data!;
                        return Column(children: [
                          Row(children: [
                            Expanded(child: _MiniCard(l.totalSales,
                                'Rs.${s.totalSales.toStringAsFixed(0)}',
                                AppColors.navy)),
                            const SizedBox(width: 8),
                            Expanded(child: _MiniCard(l.collected,
                                'Rs.${s.collected.toStringAsFixed(0)}',
                                AppColors.accent)),
                            const SizedBox(width: 8),
                            Expanded(child: _MiniCard(l.pending,
                                'Rs.${s.pending.toStringAsFixed(0)}',
                                AppColors.danger)),
                          ]),
                          const SizedBox(height: 12),
                          if (s.invoices.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(child: Column(children: [
                                  Icon(Icons.receipt_long_outlined,
                                      size: 40,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(l.noSalesOnDate,
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                ])),
                              ),
                            )
                          else
                            ...s.invoices.map((inv) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(inv.customerName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.navy)),
                                        Text(inv.invoiceNo,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ...inv.lines.map((ln) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              '${ln.itemNameSnapshot} × ${ln.qty} ${ln.unit}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          Text(
                                              'Rs.${ln.lineTotal.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    )),
                                    const Divider(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            '${l.total}: Rs.${inv.total.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.navy)),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: inv.balanceAmount == 0
                                                ? AppColors.success
                                                    .withOpacity(0.15)
                                                : AppColors.danger
                                                    .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            inv.balanceAmount == 0
                                                ? l.paidStatus
                                                : '${l.due}: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: inv.balanceAmount == 0
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                              fontWeight: FontWeight.bold,
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

                    // Credit limit alerts
                    FutureBuilder<List<Customer>>(
                      future: db.getExceededCreditLimitCustomers(),
                      builder: (ctx, snap) {
                        final exceeded = snap.data ?? [];
                        if (exceeded.isEmpty) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.warning_amber,
                                  color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${exceeded.length} ${l.creditLimitExceeded}',
                                style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ...exceeded.map((c) => FutureBuilder<double>(
                              future: db.getCustomerOutstanding(c.id),
                              builder: (ctx, snap) {
                                final out = snap.data ?? 0;
                                return Card(
                                  color:
                                      AppColors.danger.withOpacity(0.08),
                                  margin:
                                      const EdgeInsets.only(bottom: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppColors
                                                .danger
                                                .withOpacity(0.15),
                                            child: Text(
                                              c.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                  color: AppColors.danger,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(c.name,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ]),
                                        Text(
                                          'Rs.${out.toStringAsFixed(0)} / Rs.${c.creditLimit.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              color: AppColors.danger,
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
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────

class _TimeIcon extends StatelessWidget {
  final int hour;
  const _TimeIcon({required this.hour});
  @override
  Widget build(BuildContext context) {
    late IconData icon;
    late Color color;
    if (hour >= 6 && hour < 12) {
      icon = Icons.wb_sunny_outlined; color = const Color(0xFFFFDE88);
    } else if (hour >= 12 && hour < 17) {
      icon = Icons.wb_sunny;          color = const Color(0xFFFFE44A);
    } else if (hour >= 17 && hour < 21) {
      icon = Icons.wb_twilight;       color = const Color(0xFFFF9B6A);
    } else {
      icon = Icons.nights_stay_outlined; color = const Color(0xFFB0C8FF);
    }
    return Icon(icon, color: color, size: 18);
  }
}

class _SunWidget extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _SunWidget(
      {required this.size, required this.opacity, required this.color});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

class _MoonWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 36, height: 36,
          child: CustomPaint(painter: _MoonPainter()));
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        size.width * 0.45,
        Paint()..color = const Color(0xFFE8E0C8));
    canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.35),
        size.width * 0.38,
        Paint()..color = const Color(0xFF0E1F45));
  }
  @override
  bool shouldRepaint(_) => false;
}

class _StarPainter extends CustomPainter {
  static const _stars = [
    [0.12, 0.15], [0.25, 0.08], [0.38, 0.22], [0.55, 0.06],
    [0.68, 0.18], [0.78, 0.10], [0.88, 0.25], [0.05, 0.35],
    [0.45, 0.30], [0.62, 0.38], [0.82, 0.42], [0.20, 0.40],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = Colors.white.withOpacity(0.75);
    for (final s in _stars) {
      canvas.drawCircle(
          Offset(s[0] * size.width, s[1] * size.height), 1.4, p1);
    }
    final p2 = Paint()..color = Colors.white.withOpacity(0.95);
    for (final s in [[0.15, 0.25], [0.60, 0.12], [0.90, 0.35]]) {
      canvas.drawCircle(
          Offset(s[0] * size.width, s[1] * size.height), 2.2, p2);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _CloudWidget extends StatelessWidget {
  final double opacity, scale;
  const _CloudWidget({required this.opacity, required this.scale});
  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: scale,
    child: Opacity(
      opacity: opacity,
      child: SizedBox(
          width: 100, height: 40,
          child: CustomPaint(painter: _CloudPainter())),
    ),
  );
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.55),
        width: size.width * 0.9, height: size.height * 0.6), p);
    canvas.drawOval(Rect.fromCenter(
        center: Offset(size.width * 0.3, size.height * 0.45),
        width: size.width * 0.5, height: size.height * 0.65), p);
    canvas.drawOval(Rect.fromCenter(
        center: Offset(size.width * 0.68, size.height * 0.4),
        width: size.width * 0.55, height: size.height * 0.7), p);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _AnimatedStatCard extends StatefulWidget {
  final String label, value;
  final IconData icon;
  final Gradient gradient;
  final int delay;
  const _AnimatedStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.gradient,
      required this.delay});
  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(
        Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(widget.icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(widget.label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(widget.value,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

class _QuickAction extends StatefulWidget {
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
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.9,
        upperBound: 1.0)
      ..value = 1.0;
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.reverse(),
    onTapUp: (_) { _ctrl.forward(); widget.onTap(); },
    onTapCancel: () => _ctrl.forward(),
    child: ScaleTransition(
      scale: _ctrl,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(widget.icon, size: 26, color: widget.color),
        ),
        const SizedBox(height: 6),
        Text(widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500)),
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
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Column(children: [
      Text(label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center),
    ]),
  );
}
