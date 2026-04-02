import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../database/app_database.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<StaffUser> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await context.read<AppDatabase>().getAllStaff();
    if (mounted) {
      setState(() {
        _staff = list;
        _loading = false;
      });
    }
  }

  String _hashPin(String pin) {
    // Simple hash for PIN storage
    var hash = 0;
    for (final c in pin.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<void> _showAddEditDialog({StaffUser? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');
    final pinCtrl = TextEditingController();
    String role = existing?.role ?? 'SALESPERSON';
    bool canInvoice = existing?.canCreateInvoice ?? true;
    bool canReports = existing?.canViewReports ?? false;
    bool canCustomers = existing?.canManageCustomers ?? true;
    bool canItems = existing?.canManageItems ?? false;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title:
              Text(existing == null ? 'Add Staff' : 'Edit Staff'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person)),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Phone *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+91 '),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) =>
                        v == null || v.length != 10
                            ? 'Enter 10-digit number'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pinCtrl,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? '4-digit PIN *'
                          : '4-digit PIN (leave blank to keep)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (v) {
                      if (existing == null &&
                          (v == null || v.length != 4)) {
                        return '4-digit PIN required';
                      }
                      if (v != null &&
                          v.isNotEmpty &&
                          v.length != 4) {
                        return 'Must be exactly 4 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'OWNER',
                          child: Text('Owner (Full Access)')),
                      DropdownMenuItem(
                          value: 'MANAGER',
                          child: Text('Manager')),
                      DropdownMenuItem(
                          value: 'SALESPERSON',
                          child: Text('Salesperson')),
                    ],
                    onChanged: (v) {
                      setDlg(() {
                        role = v!;
                        if (role == 'OWNER') {
                          canInvoice = true;
                          canReports = true;
                          canCustomers = true;
                          canItems = true;
                        } else if (role == 'SALESPERSON') {
                          canInvoice = true;
                          canReports = false;
                          canCustomers = true;
                          canItems = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Permissions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  SwitchListTile(
                    title: const Text('Create Invoices',
                        style: TextStyle(fontSize: 13)),
                    value: canInvoice,
                    dense: true,
                    onChanged: (v) =>
                        setDlg(() => canInvoice = v),
                  ),
                  SwitchListTile(
                    title: const Text('View Reports',
                        style: TextStyle(fontSize: 13)),
                    value: canReports,
                    dense: true,
                    onChanged: (v) =>
                        setDlg(() => canReports = v),
                  ),
                  SwitchListTile(
                    title: const Text('Manage Customers',
                        style: TextStyle(fontSize: 13)),
                    value: canCustomers,
                    dense: true,
                    onChanged: (v) =>
                        setDlg(() => canCustomers = v),
                  ),
                  SwitchListTile(
                    title: const Text('Manage Items',
                        style: TextStyle(fontSize: 13)),
                    value: canItems,
                    dense: true,
                    onChanged: (v) =>
                        setDlg(() => canItems = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final db = context.read<AppDatabase>();

    if (existing == null) {
      await db.createStaff(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        pin: _hashPin(pinCtrl.text.trim()),
        role: role,
        canCreateInvoice: canInvoice,
        canViewReports: canReports,
        canManageCustomers: canCustomers,
        canManageItems: canItems,
      );
    } else {
      await db.updateStaff(existing.copyWith(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        pin: pinCtrl.text.trim().isNotEmpty
            ? _hashPin(pinCtrl.text.trim())
            : existing.pin,
        role: role,
        canCreateInvoice: canInvoice,
        canViewReports: canReports,
        canManageCustomers: canCustomers,
        canManageItems: canItems,
      ));
    }
    _load();
  }

  Future<void> _toggleActive(StaffUser s) async {
    await context.read<AppDatabase>().updateStaff(
        s.copyWith(isActive: !s.isActive));
    _load();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'OWNER':
        return Colors.purple;
      case 'MANAGER':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 64,
                          color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No staff added yet',
                          style:
                              TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      const Text(
                          'Tap + to add staff members',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _staff.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final s = _staff[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(children: [
                            CircleAvatar(
                              backgroundColor:
                                  _roleColor(s.role)
                                      .withOpacity(0.15),
                              child: Text(
                                s.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: _roleColor(s.role),
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
                                  Text(s.name,
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          color: s.isActive
                                              ? null
                                              : Colors.grey)),
                                  Text('+91 ${s.phone}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        _roleColor(s.role)
                                            .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(
                                            4),
                                  ),
                                  child: Text(
                                    s.role,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            _roleColor(s.role),
                                        fontWeight:
                                            FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.isActive
                                      ? 'Active'
                                      : 'Inactive',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: s.isActive
                                          ? Colors.green
                                          : Colors.red),
                                ),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 8),
                          // Permissions chips
                          Wrap(spacing: 4, children: [
                            if (s.canCreateInvoice)
                              _permChip('Invoice', Colors.green),
                            if (s.canViewReports)
                              _permChip('Reports', Colors.blue),
                            if (s.canManageCustomers)
                              _permChip(
                                  'Customers', Colors.orange),
                            if (s.canManageItems)
                              _permChip('Items', Colors.purple),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit,
                                    size: 14),
                                label: const Text('Edit'),
                                onPressed: () =>
                                    _showAddEditDialog(
                                        existing: s),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  s.isActive
                                      ? Icons.block
                                      : Icons.check_circle,
                                  size: 14,
                                  color: s.isActive
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                label: Text(
                                  s.isActive
                                      ? 'Deactivate'
                                      : 'Activate',
                                  style: TextStyle(
                                      color: s.isActive
                                          ? Colors.red
                                          : Colors.green),
                                ),
                                onPressed: () =>
                                    _toggleActive(s),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _permChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: color)),
      );
}
