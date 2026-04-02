import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/app_database.dart';

class PaymentRemindersScreen extends StatefulWidget {
  const PaymentRemindersScreen({Key? key}) : super(key: key);
  @override
  State<PaymentRemindersScreen> createState() =>
      _PaymentRemindersScreenState();
}

class _ReminderCustomer {
  final Customer customer;
  final double outstanding;
  final int daysSinceLastInvoice;
  final String lastInvoiceNo;
  final int lastInvoiceDate;
  bool selected;

  _ReminderCustomer({
    required this.customer,
    required this.outstanding,
    required this.daysSinceLastInvoice,
    required this.lastInvoiceNo,
    required this.lastInvoiceDate,
    this.selected = false,
  });
}

class _PaymentRemindersScreenState
    extends State<PaymentRemindersScreen> {
  List<_ReminderCustomer> _customers = [];
  bool _loading = true;
  int _filterDays = 7; // show pending for 7+ days by default

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final allCustomers = await db.getAllCustomers();
    final result = <_ReminderCustomer>[];

    for (final c in allCustomers) {
      final outstanding = await db.getCustomerOutstanding(c.id);
      if (outstanding <= 0) continue;

      final invoices = await db.getCustomerInvoices(c.id);
      final pendingInvoices =
          invoices.where((i) => i.balanceAmount > 0).toList();
      if (pendingInvoices.isEmpty) continue;

      final lastInvoice = pendingInvoices.first;
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(
              lastInvoice.invoiceDate))
          .inDays;

      result.add(_ReminderCustomer(
        customer: c,
        outstanding: outstanding,
        daysSinceLastInvoice: daysSince,
        lastInvoiceNo: lastInvoice.invoiceNo,
        lastInvoiceDate: lastInvoice.invoiceDate,
      ));
    }

    // Sort by outstanding amount descending
    result.sort((a, b) =>
        b.outstanding.compareTo(a.outstanding));

    if (mounted) {
      setState(() {
        _customers = result;
        _loading = false;
      });
    }
  }

  List<_ReminderCustomer> get _filtered => _customers
      .where((c) => c.daysSinceLastInvoice >= _filterDays)
      .toList();

  List<_ReminderCustomer> get _selected =>
      _filtered.where((c) => c.selected).toList();

  Future<void> _sendReminder(_ReminderCustomer rc,
      {String? shopName}) async {
    final fmt = DateFormat('dd/MM/yyyy');
    final name = rc.customer.name;
    final amount =
        rc.outstanding.toStringAsFixed(0);
    final invoiceNo = rc.lastInvoiceNo;
    final date = fmt.format(
        DateTime.fromMillisecondsSinceEpoch(
            rc.lastInvoiceDate));
    final shop = shopName ?? 'VyapaarX';

    final msg = Uri.encodeComponent(
      '🙏 Dear *$name*,\n\n'
      'This is a gentle reminder for your outstanding payment.\n\n'
      '📋 Invoice: *$invoiceNo*\n'
      '📅 Date: $date\n'
      '💰 Amount Due: *Rs. $amount*\n\n'
      'Kindly clear the payment at your earliest convenience.\n\n'
      'Thank you for your business! 🙏\n\n'
      '— *$shop*\n'
      '_Sent via VyapaarX_',
    );

    final url =
        Uri.parse('whatsapp://send?phone=91${rc.customer.phone}&text=$msg');
    final fallback =
        Uri.parse('https://wa.me/91${rc.customer.phone}?text=$msg');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(fallback,
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open WhatsApp for ${rc.customer.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendBulkReminders() async {
    final db = context.read<AppDatabase>();
    final shopName =
        await db.getSetting('shop_name') ?? 'VyapaarX';
    final selected = _selected;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one customer')),
      );
      return;
    }

    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Send ${selected.length} Reminders?'),
        content: Text(
            'WhatsApp will open for each customer one by one. '
            'You\'ll need to tap Send in WhatsApp for each.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true) return;

    for (final rc in selected) {
      await _sendReminder(rc, shopName: shopName);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final selectedCount = _selected.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reminders'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Filter bar
        Container(
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.3),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(children: [
            const Text('Show pending since: ',
                style: TextStyle(fontSize: 13)),
            const Spacer(),
            DropdownButton<int>(
              value: _filterDays,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('All')),
                DropdownMenuItem(value: 3, child: Text('3+ days')),
                DropdownMenuItem(value: 7, child: Text('7+ days')),
                DropdownMenuItem(
                    value: 15, child: Text('15+ days')),
                DropdownMenuItem(
                    value: 30, child: Text('30+ days')),
              ],
              onChanged: (v) =>
                  setState(() => _filterDays = v!),
            ),
          ]),
        ),

        // Summary bar
        if (!_loading && filtered.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(children: [
              Text(
                '${filtered.length} customers pending  •  '
                'Rs.${filtered.fold(0.0, (s, c) => s + c.outstanding).toStringAsFixed(0)} total',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (selectedCount > 0)
                Text('$selectedCount selected',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
            ]),
          ),

        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _customers.isEmpty
                                ? 'No pending payments! 🎉'
                                : 'No pending payments for $_filterDays+ days',
                            style: const TextStyle(
                                color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final rc = filtered[i];
                          final isUrgent =
                              rc.daysSinceLastInvoice >= 30;
                          final isWarning =
                              rc.daysSinceLastInvoice >= 15;

                          return CheckboxListTile(
                            value: rc.selected,
                            onChanged: (v) => setState(
                                () => rc.selected = v!),
                            activeColor: Colors.green,
                            secondary: CircleAvatar(
                              backgroundColor: isUrgent
                                  ? Colors.red.shade100
                                  : isWarning
                                      ? Colors.orange.shade100
                                      : Colors.yellow.shade100,
                              child: Text(
                                rc.customer.name[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: isUrgent
                                      ? Colors.red
                                      : isWarning
                                          ? Colors.orange
                                          : Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              rc.customer.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${rc.lastInvoiceNo}  •  ${rc.daysSinceLastInvoice} days ago',
                              style: const TextStyle(
                                  fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs.${rc.outstanding.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isUrgent
                                        ? Colors.red
                                        : Colors.orange,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _sendReminder(rc),
                                  child: Container(
                                    margin: const EdgeInsets
                                        .only(top: 4),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                          0xFF25D366),
                                      borderRadius:
                                          BorderRadius.circular(
                                              4),
                                    ),
                                    child: const Text(
                                      '📱 Remind',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
      bottomNavigationBar: filtered.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  OutlinedButton(
                    onPressed: () => setState(() {
                      final allSelected = filtered
                          .every((c) => c.selected);
                      for (final c in filtered) {
                        c.selected = !allSelected;
                      }
                    }),
                    child: const Text('Select All'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text(
                        selectedCount > 0
                            ? 'Send $selectedCount Reminders'
                            : 'Select customers first',
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF25D366)),
                      onPressed: selectedCount > 0
                          ? _sendBulkReminders
                          : null,
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}
