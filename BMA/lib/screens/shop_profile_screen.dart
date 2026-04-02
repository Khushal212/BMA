import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({Key? key}) : super(key: key);
  @override
  State<ShopProfileScreen> createState() =>
      _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final db = context.read<AppDatabase>();
    _nameCtrl.text = await db.getSetting('shop_name') ?? '';
    _addressCtrl.text = await db.getSetting('shop_address') ?? '';
    _phoneCtrl.text = await db.getSetting('shop_phone') ?? '';
    _gstinCtrl.text = await db.getSetting('shop_gstin') ?? '';
    _upiCtrl.text = await db.getSetting('shop_upi') ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    await db.saveSetting('shop_name', _nameCtrl.text.trim());
    await db.saveSetting('shop_address', _addressCtrl.text.trim());
    await db.saveSetting('shop_phone', _phoneCtrl.text.trim());
    await db.saveSetting('shop_gstin', _gstinCtrl.text.trim().toUpperCase());
    await db.saveSetting('shop_upi', _upiCtrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop profile saved ✓'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // GSTIN validator
  String? _validateGSTIN(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final gstin = v.trim().toUpperCase();
    final gstinRegex = RegExp(
        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstinRegex.hasMatch(gstin)) {
      return 'Invalid GSTIN format (e.g. 27AAPFU0939F1ZV)';
    }
    return null;
  }

  String? _validateUPI(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    if (!v.contains('@')) return 'Invalid UPI ID (e.g. name@upi)';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Profile'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header info card
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This info will appear on your invoice PDF header.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Business Information',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop / Business Name *',
                        hintText: 'e.g. Ram Vegetables',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Shop name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        hintText: 'Shop address, city, pincode',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        hintText: '10-digit mobile number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+91 ',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone is required';
                        }
                        if (v.trim().length != 10) {
                          return 'Enter 10-digit number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    const Text('Tax & Payment',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (optional)',
                        hintText: 'e.g. 27AAPFU0939F1ZV',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(15),
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                      ],
                      validator: _validateGSTIN,
                      autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _upiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID (optional)',
                        hintText: 'e.g. yourname@paytm',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                        helperText:
                            'Customers can scan QR to pay you directly',
                      ),
                      validator: _validateUPI,
                      autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                    ),

                    // UPI QR preview
                    if (_upiCtrl.text.trim().isNotEmpty &&
                        _upiCtrl.text.contains('@')) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            const Text('QR Preview',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'QR code will be generated on invoice PDF',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Text(
                                'upi://pay?pa=${_upiCtrl.text.trim()}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.blue),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Shop Profile',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
