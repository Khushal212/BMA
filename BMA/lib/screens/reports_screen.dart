import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Monthly'),
            Tab(icon: Icon(Icons.date_range), text: 'Weekly'),
            Tab(icon: Icon(Icons.person), text: 'Customer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _MonthlyTab(),
          _WeeklyTab(),
          _CustomerReportTab(),
        ],
      ),
    );
  }
}

// ── MONTHLY TAB ───────────────────────────────────────────────
class _MonthlyTab extends StatefulWidget {
  const _MonthlyTab();
  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  final now = DateTime.now();
  late int _year;
  late int _month;
  PeriodSummary? _summary;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _month = DateTime.now().month;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final s = await db.getMonthlySummary(_year, _month);
    if (mounted) setState(() { _summary = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(_year, _month));
    return Column(children: [
      // Month selector
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  if (_month == 1) { _month = 12; _year--; }
                  else _month--;
                });
                _load();
              },
            ),
            Text(monthName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                if (DateTime(_year, _month)
                    .isBefore(DateTime(now.year, now.month))) {
                  setState(() {
                    if (_month == 12) { _month = 1; _year++; }
                    else _month++;
                  });
                  _load();
                }
              },
            ),
          ],
        ),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_summary == null)
        const Expanded(child: Center(child: Text('No data')))
      else
        Expanded(child: _SummaryBody(summary: _summary!)),
    ]);
  }
}

// ── WEEKLY TAB ────────────────────────────────────────────────
class _WeeklyTab extends StatefulWidget {
  const _WeeklyTab();
  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  late DateTime _weekStart;
  PeriodSummary? _summary;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final s = await db.getWeeklySummary(_weekStart);
    if (mounted) setState(() { _summary = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM');
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final label = '${fmt.format(_weekStart)} - ${fmt.format(weekEnd)}';

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _weekStart =
                    _weekStart.subtract(const Duration(days: 7)));
                _load();
              },
            ),
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                if (_weekStart
                    .isBefore(DateTime.now().subtract(const Duration(days: 7)))) {
                  setState(() => _weekStart =
                      _weekStart.add(const Duration(days: 7)));
                  _load();
                }
              },
            ),
          ],
        ),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_summary == null)
        const Expanded(child: Center(child: Text('No data')))
      else
        Expanded(child: _SummaryBody(summary: _summary!)),
    ]);
  }
}

// ── SHARED SUMMARY BODY ───────────────────────────────────────
class _SummaryBody extends StatelessWidget {
  final PeriodSummary summary;
  const _SummaryBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dayEntries = summary.dayWiseSales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxSale = dayEntries.isEmpty ? 1.0
        : dayEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          Row(children: [
            Expanded(child: _Card('Total Sales',
                'Rs.${summary.totalSales.toStringAsFixed(0)}',
                Colors.green, Icons.trending_up)),
            const SizedBox(width: 8),
            Expanded(child: _Card('Collected',
                'Rs.${summary.totalCollected.toStringAsFixed(0)}',
                Colors.blue, Icons.check_circle)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Card('Pending',
                'Rs.${summary.totalPending.toStringAsFixed(0)}',
                Colors.red, Icons.pending)),
            const SizedBox(width: 8),
            Expanded(child: _Card('Invoices',
                '${summary.invoiceCount}',
                Colors.orange, Icons.receipt)),
          ]),
          const SizedBox(height: 20),

          // Day-wise bar chart
          if (dayEntries.isNotEmpty) ...[
            const Text('Day-wise Sales',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...dayEntries.map((e) {
              final pct = maxSale > 0 ? e.value / maxSale : 0.0;
              final day = e.key.substring(8); // day number
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text(day,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ),
                  Expanded(
                    child: Stack(children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct.toDouble(),
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                        'Rs.${e.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No sales in this period',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _Card(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color.withOpacity(0.8))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}

// ── CUSTOMER REPORT TAB ───────────────────────────────────────
class _CustomerReportTab extends StatefulWidget {
  const _CustomerReportTab();
  @override
  State<_CustomerReportTab> createState() =>
      _CustomerReportTabState();
}

class _CustomerReportTabState
    extends State<_CustomerReportTab> {
  List<Customer> _customers = [];
  Customer? _selected;
  CustomerReport? _report;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final list =
        await context.read<AppDatabase>().getAllCustomers();
    if (mounted) setState(() => _customers = list);
  }

  Future<void> _loadReport(String customerId) async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final r = await db.getCustomerReport(customerId);
    if (mounted) setState(() { _report = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: _selected?.id,
          decoration: const InputDecoration(
            labelText: 'Select Customer',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          items: _customers.map((c) => DropdownMenuItem(
              value: c.id, child: Text(c.name))).toList(),
          onChanged: (v) {
            _selected =
                _customers.firstWhere((c) => c.id == v);
            _loadReport(v!);
          },
        ),
      ),
      if (_loading)
        const Expanded(
            child: Center(child: CircularProgressIndicator()))
      else if (_report == null)
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Select a customer to view report',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        )
      else
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Row(children: [
                  Expanded(child: _Card('Total Business',
                      'Rs.${_report!.totalBusiness.toStringAsFixed(0)}',
                      Colors.purple, Icons.business)),
                  const SizedBox(width: 8),
                  Expanded(child: _Card('Outstanding',
                      'Rs.${_report!.outstanding.toStringAsFixed(0)}',
                      _report!.outstanding > 0
                          ? Colors.red : Colors.green,
                      Icons.account_balance_wallet)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _Card('Invoices',
                      '${_report!.totalInvoices}',
                      Colors.blue, Icons.receipt)),
                  const SizedBox(width: 8),
                  Expanded(child: _Card('Total Paid',
                      'Rs.${_report!.totalPaid.toStringAsFixed(0)}',
                      Colors.green, Icons.check_circle)),
                ]),
                const SizedBox(height: 20),

                // Items purchased
                const Text('Items Purchased',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                ..._report!.itemBreakdown.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Colors.purple.shade100,
                          child: Text(
                              item['itemName'][0].toUpperCase()
                              style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item['itemName']),
                        subtitle: Text(
                            '${item['totalQty'].toStringAsFixed(1)} ${item['unit']}'),
                        trailing: Text(
                            'Rs.${item['totalAmount'].toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    )),
                const SizedBox(height: 16),

                // Recent invoices
                const Text('Recent Invoices',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 8),
                ..._report!.invoices.take(10).map((inv) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        title: Text(inv.invoiceNo),
                        subtitle: Text(fmt.format(
                            DateTime.fromMillisecondsSinceEpoch(
                                inv.invoiceDate))),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                                'Rs.${inv.total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              inv.balanceAmount == 0
                                  ? 'PAID'
                                  : 'Due: Rs.${inv.balanceAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: inv.balanceAmount == 0
                                      ? Colors.green
                                      : Colors.red),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
    ]);
  }
}
