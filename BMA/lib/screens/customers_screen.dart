import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/app_database.dart';
import '../main.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await context.read<AppDatabase>().getAllCustomers();
    if (mounted) setState(() { _customers = list; _loading = false; });
  }

  List<Customer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) =>
      c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q)).toList();
  }

  Future<void> _callCustomer(String phone) async {
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotLaunchDialer)));
      }
    }
  }

  Future<void> _importFromContacts() async {
    final l = context.l10n;
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.contactsPermissionDenied),
          action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
        ));
      }
      return;
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    final contacts = await ContactsService.getContacts(withThumbnails: false);
    if (mounted) Navigator.pop(context);

    final validContacts = contacts
        .where((c) => c.phones != null && c.phones!.isNotEmpty)
        .toList()
      ..sort((a, b) => (a.displayName ?? '').compareTo(b.displayName ?? ''));

    if (validContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.noContactsFound)));
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ContactPickerSheet(
        contacts: validContacts,
        existingPhones: _customers.map((c) => c.phone).toSet(),
        onContactSelected: (name, phone) async {
          Navigator.pop(ctx);
          await _showAddEditDialogPrefilled(name: name, phone: phone);
        },
      ),
    );
  }

  String? _validateName(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return l.nameRequired;
    if (v.trim().length < 2) return l.nameTooShort;
    if (v.trim().length > 50) return l.nameTooLong;
    return null;
  }

  String? _validatePhone(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return l.phoneRequired;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return l.invalidPhone;
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return l.phoneStartDigit;
    return null;
  }

  String? _validateCreditLimit(String? v) {
    final l = context.l10n;
    if (v == null || v.trim().isEmpty) return l.creditLimitRequired;
    final amount = double.tryParse(v.trim());
    if (amount == null) return l.invalidNumber;
    if (amount < 0) return l.cannotBeNegative;
    return null;
  }

  Future<void> _showAddEditDialogPrefilled({String name = '', String phone = ''}) =>
      _showAddEditDialog(prefillName: name, prefillPhone: phone);

  Future<void> _showAddEditDialog({Customer? existing, String prefillName = '', String prefillPhone = ''}) async {
    final l = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? prefillName);
    final phoneCtrl = TextEditingController(text: existing?.phone ?? prefillPhone);
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final limitCtrl = TextEditingController(
        text: (existing?.creditLimit ?? 10000).toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? l.addCustomer : l.editCustomer),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: l.customerName,
                  hintText: l.customerNameHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: l.customerPhone,
                  hintText: l.customerPhoneHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _validatePhone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addrCtrl,
                decoration: InputDecoration(
                  labelText: l.customerAddress,
                  hintText: l.customerAddressHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: limitCtrl,
                decoration: InputDecoration(
                  labelText: l.creditLimit,
                  hintText: l.creditLimitHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.credit_card),
                  prefixText: 'Rs. ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateCreditLimit,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); },
            child: Text(l.save),
          ),
        ],
      ),
    );

    if (result != true) return;
    final db = context.read<AppDatabase>();
    if (existing == null) {
      await db.createCustomer(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
        creditLimit: double.parse(limitCtrl.text.trim()),
      );
    } else {
      await db.updateCustomer(Customer(
        id: existing.id,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
        creditLimit: double.parse(limitCtrl.text.trim()),
        defaultPricePercent: existing.defaultPricePercent,
        defaultGstPercent: existing.defaultGstPercent,
        createdAt: existing.createdAt,
      ));
    }
    _loadCustomers();
  }

  Future<void> _deleteCustomer(Customer c) async {
    final l = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteCustomer),
        content: Text('${l.deleteCustomer} "${c.name}"? ${l.deleteCustomerConfirm}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await context.read<AppDatabase>().deleteCustomer(c.id);
    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customers),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts, color: Colors.white),
            tooltip: l.importFromContacts,
            onPressed: _importFromContacts,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('${_customers.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l.searchNameOrPhone,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchController.clear(); setState(() => _query = ''); })
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: GestureDetector(
            onTap: _importFromContacts,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.navy.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.contacts, color: AppColors.navy, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(l.importFromContacts,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.navy.withOpacity(0.5)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _customers.isEmpty ? l.noCustomersYet : 'No results for "$_query"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCustomers,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final c = _filtered[idx];
                          return FutureBuilder<double>(
                            future: context.read<AppDatabase>().getCustomerOutstanding(c.id),
                            builder: (ctx, snap) {
                              final out = snap.data ?? 0;
                              final exceeded = out > c.creditLimit;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: exceeded
                                      ? Colors.red.shade100
                                      : AppColors.navy.withOpacity(0.1),
                                  child: Text(c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: exceeded ? Colors.red : AppColors.navy,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(c.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('+91 ${c.phone}'),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Column(mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Rs.${out.toStringAsFixed(0)}',
                                            style: TextStyle(
                                                color: exceeded ? Colors.red : AppColors.navy,
                                                fontWeight: FontWeight.bold)),
                                        Text('${l.limit}: Rs.${c.creditLimit.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ]),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.call, size: 18, color: Colors.green),
                                    onPressed: () => _callCustomer(c.phone),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 18, color: AppColors.navy),
                                    onPressed: () => _showAddEditDialog(existing: c),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ]),
                                onTap: () async {
                                  await Navigator.push(ctx,
                                      MaterialPageRoute(builder: (_) =>
                                          CustomerDetailScreen(customerId: c.id)));
                                  _loadCustomers();
                                },
                                onLongPress: () => _showAddEditDialog(existing: c),
                              );
                            },
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  final Set<String> existingPhones;
  final Function(String name, String phone) onContactSelected;
  const _ContactPickerSheet({
    required this.contacts,
    required this.existingPhones,
    required this.onContactSelected,
  });
  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  List<Contact> get _filtered {
    if (_search.isEmpty) return widget.contacts;
    return widget.contacts.where((c) =>
        (c.displayName ?? '').toLowerCase().contains(_search.toLowerCase()) ||
        (c.phones?.any((p) =>
                p.value?.replaceAll(RegExp(r'\D'), '').contains(_search) ??
                false) ??
            false)).toList();
  }

  String _cleanPhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) digits = digits.substring(2);
    if (digits.startsWith('+91')) digits = digits.substring(3);
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(l.importFromContactsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text('${widget.contacts.length} ${l.contacts}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: l.searchContacts,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            controller: ctrl,
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final contact = _filtered[i];
              final name = contact.displayName ?? 'Unknown';
              final rawPhone = contact.phones?.first.value ?? '';
              final phone = _cleanPhone(rawPhone);
              final alreadyAdded = widget.existingPhones.contains(phone);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: alreadyAdded ? Colors.grey.shade200 : AppColors.navy.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: alreadyAdded ? Colors.grey : AppColors.navy,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: alreadyAdded ? Colors.grey : null)),
                subtitle: Text(phone.isNotEmpty ? '+91 $phone' : rawPhone),
                trailing: alreadyAdded
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(l.alreadyAdded,
                            style: const TextStyle(fontSize: 11, color: Colors.grey)))
                    : ElevatedButton(
                        onPressed: () => widget.onContactSelected(name, phone),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l.add, style: const TextStyle(fontSize: 12)),
                      ),
                onTap: alreadyAdded ? null : () => widget.onContactSelected(name, phone),
              );
            },
          ),
        ),
      ]),
    );
  }
}
