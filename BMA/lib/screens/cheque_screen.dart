import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

// Cheque stored in Settings as JSON list under key 'cheques'
// Each cheque: {id, customerId, customerName, chequeNo, bank,
//               amount, dueDate, status, notes, createdAt}

class ChequeScreen extends StatefulWidget {
  const ChequeScreen({Key? key}) : super(key: key);
  @override
  State<ChequeScreen> createState() => _ChequeScreenState();
}

class _ChequeEntry {
  final String id, customerId, customerName,
      chequeNo, bank, notes;
  final double amount;
  final DateTime dueDate;
  String status; // PENDING, DEPOSITED, BOUNCED

  _ChequeEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.chequeNo,
    required this.bank,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'chequeNo': chequeNo,
        'bank': bank,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'status': status,
        'notes': notes,
      };

  static _ChequeEntry fromJson(Map<String, dynamic> j) =>
      _ChequeEntry(
        id: j['id'],
        customerId: j['customerId'],
        customerName: j['customerName'],
        chequeNo: j['chequeNo'],
        bank: j['bank'],
        amount: (j['amount'] as num).toDouble(),
        dueDate: DateTime.parse(j['dueDate']),
        status: j['status'],
        notes: j['notes'] ?? '',
      );
}

class _ChequeScreenState extends State<ChequeScreen> {
  List<_ChequeEntry> _cheques = [];
  List<Customer> _customers = [];
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<AppDatabase>();
    final customers = await db.getAllCustomers();
    final saved = await db.getSetting('cheques') ?? '[]';
    final List<dynamic> list =
        _parseJson(saved);
    final cheques = list
        .map((e) =>
            _ChequeEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (mounted) {
      setState(() {
        _customers = customers;
        _cheques = cheques;
        _loading = false;
      });
    }
  }

  List<dynamic> _parseJson(String s) {
    try {
      // Simple JSON array parser
      if (s == '[]' || s.isEmpty) return [];
      s = s.trim();
      if (!s.startsWith('[')) return [];
      // Use dart:convert
      return _jsonDecode(s);
    } catch (_) {
      return [];
    }
  }

  List<dynamic> _jsonDecode(String s) {
    // We'll use dart:convert via import
    import 'dart:convert';
    return jsonDecode(s) as List<dynamic>;
  }

  Future<void> _saveAll() async {
    final import = "import 'dart:convert';";
    final json = '[${_cheques.map((c) {
      final m = c.toJson();
      return '{"id":"${m['id']}","customerId":"${m['customerId']}",'
          '"customerName":"${m['customerName']}","chequeNo":"${m['chequeNo']}",'
          '"bank":"${m['bank']}","amount":${m['amount']},'
          '"dueDate":"${m['dueDate']}","status":"${m['status']}",'
          '"notes":"${m['notes']}"}';
    }).join(',')}]';
    await context.read<AppDatabase>().saveSetting('cheques', json);
  }

  List<_ChequeEntry> get _filtered {
    if (_filter == 'All') return _cheques;
    return _cheques
        .where((c) => c.status == _filter)
        .toList();
  }

  Future<void> _addCheque() async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add customers first')));
      return;
    }
    final chequeNoCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    Customer? selectedCust = _customers.first;
    DateTime dueDate =
        DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();
    final fmt = DateFormat('dd MMM yyyy');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add Cheque'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCust?.id,
                      decoration: const InputDecoration(
                          labelText: 'Customer *',
                          border: OutlineInputBorder()),
                      items: _customers
                          .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setDlg(() =>
                          selectedCust = _customers
                              .firstWhere((c) => c.id == v)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: chequeNoCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Cheque Number *',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) =>
                          v == null || v.isEmpty
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Bank Name *',
                          hintText: 'e.g. SBI, HDFC',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          v == null || v.isEmpty
                              ? 'Required'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amtCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Amount *',
                          border: OutlineInputBorder(),
                          prefixText: 'Rs. '),
                      keyboardType:
                          TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                      validator: (v) =>
                          double.tryParse(v ?? '') == null
                              ? 'Invalid'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked =
                            await showDatePicker(
                          context: ctx,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                              const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDlg(() => dueDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Due Date *',
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_today)),
                        child: Text(fmt.format(dueDate)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder()),
                    ),
                  ]),
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
                child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result != true) return;
    _cheques.add(_ChequeEntry(
      id: const Uuid().v4(),
      customerId: selectedCust!.id,
      customerName: selectedCust!.name,
      chequeNo: chequeNoCtrl.text.trim(),
      bank: bankCtrl.text.trim(),
      amount: double.parse(amtCtrl.text.trim()),
      dueDate: dueDate,
      status: 'PENDING',
      notes: notesCtrl.text.trim(),
    ));
    await _saveAll();
    _load();
  }

  Future<void> _updateStatus(
      _ChequeEntry c, String newStatus) async {
    setState(() => c.status = newStatus);
    await _saveAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cheque marked as $newStatus'),
          backgroundColor: newStatus == 'DEPOSITED'
              ? Colors.green
              : Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DEPOSITED':
        return Colors.green;
      case 'BOUNCED':
        return Colors.red;
      default:
        final now = DateTime.now();
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final filtered = _filtered;
    final totalPending = _cheques
        .where((c) => c.status == 'PENDING')
        .fold(0.0, (s, c) => s + c.amount);
    final dueSoon = _cheques
        .where((c) =>
            c.status == 'PENDING' &&
            c.dueDate.difference(DateTime.now()).inDays <= 3)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheque Management'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCheque,
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        // Alert banner
        if (dueSoon > 0)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.warning,
                  color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                '$dueSoon cheque(s) due within 3 days! '
                'Total pending: Rs.${totalPending.toStringAsFixed(0)}',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ]),
          ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          child: Row(children: [
            for (final f in [
              'All', 'PENDING', 'DEPOSITED', 'BOUNCED'
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f == 'All' ? 'All' : f),
                  selected: _filter == f,
                  onSelected: (_) =>
                      setState(() => _filter = f),
                  selectedColor:
                      f == 'DEPOSITED'
                          ? Colors.green.shade100
                          : f == 'BOUNCED'
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                ),
              ),
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
                          Icon(Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                              'No cheques found',
                              style: TextStyle(
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text(
                              'Tap + to add a cheque',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final daysLeft = c.dueDate
                            .difference(DateTime.now())
                            .inDays;
                        final isUrgent =
                            daysLeft <= 3 &&
                                c.status == 'PENDING';
                        final isOverdue =
                            daysLeft < 0 &&
                                c.status == 'PENDING';

                        return Card(
                          color: isUrgent
                              ? Colors.red.shade50
                              : null,
                          child: Padding(
                            padding:
                                const EdgeInsets.all(12),
                            child: Column(children: [
                              Row(children: [
                                CircleAvatar(
                                  backgroundColor:
                                      _statusColor(c.status)
                                          .withOpacity(0.15),
                                  child: Text(
                                    c.customerName[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _statusColor(
                                          c.status),
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
                                      Text(
                                          c.customerName,
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                      Text(
                                        'Cheque #${c.chequeNo} • ${c.bank}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs.${c.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                                c.status)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius
                                                .circular(4),
                                      ),
                                      child: Text(
                                        c.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _statusColor(
                                              c.status),
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(Icons.calendar_today,
                                    size: 14,
                                    color: isOverdue
                                        ? Colors.red
                                        : isUrgent
                                            ? Colors.orange
                                            : Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Due: ${fmt.format(c.dueDate)}  •  '
                                  '${isOverdue ? "OVERDUE ${(-daysLeft)} days" : daysLeft == 0 ? "Due TODAY!" : "In $daysLeft days"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOverdue
                                        ? Colors.red
                                        : isUrgent
                                            ? Colors.orange
                                            : Colors.grey,
                                    fontWeight: isUrgent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ]),
                              if (c.status == 'PENDING') ...[
                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _updateStatus(
                                              c, 'DEPOSITED'),
                                      style: OutlinedButton
                                          .styleFrom(
                                              foregroundColor:
                                                  Colors.green,
                                              side:
                                                  const BorderSide(
                                                      color: Colors
                                                          .green)),
                                      child: const Text(
                                          '✓ Deposited'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _updateStatus(
                                              c, 'BOUNCED'),
                                      style: OutlinedButton
                                          .styleFrom(
                                              foregroundColor:
                                                  Colors.red,
                                              side:
                                                  const BorderSide(
                                                      color:
                                                          Colors.red)),
                                      child: const Text(
                                          '✗ Bounced'),
                                    ),
                                  ),
                                ]),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
