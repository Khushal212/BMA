import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../database/app_database.dart';
import '../main.dart';

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

  // Custom QR image (stored as base64 in settings)
  String? _customQrBase64;
  bool _useCustomQr = false;

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
    _addressCtrl.text =
        await db.getSetting('shop_address') ?? '';
    _phoneCtrl.text = await db.getSetting('shop_phone') ?? '';
    _gstinCtrl.text = await db.getSetting('shop_gstin') ?? '';
    _upiCtrl.text = await db.getSetting('shop_upi') ?? '';
    final customQr = await db.getSetting('shop_custom_qr');
    final useCustom =
        await db.getSetting('shop_use_custom_qr');
    if (mounted) {
      setState(() {
        _customQrBase64 = customQr;
        _useCustomQr = useCustom == 'true';
        _loading = false;
      });
    }
  }

  Future<void> _pickQrImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload QR Code'),
        content: const Text(
            'Choose where to get your QR code image from:'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            onPressed: () =>
                Navigator.pop(ctx, ImageSource.gallery),
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            onPressed: () =>
                Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _customQrBase64 = base64Str;
        _useCustomQr = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR image uploaded ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeCustomQr() async {
    setState(() {
      _customQrBase64 = null;
      _useCustomQr = false;
    });
    final db = context.read<AppDatabase>();
    await db.saveSetting('shop_custom_qr', '');
    await db.saveSetting('shop_use_custom_qr', 'false');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom QR removed')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    await db.saveSetting(
        'shop_name', _nameCtrl.text.trim());
    await db.saveSetting(
        'shop_address', _addressCtrl.text.trim());
    await db.saveSetting(
        'shop_phone', _phoneCtrl.text.trim());
    await db.saveSetting('shop_gstin',
        _gstinCtrl.text.trim().toUpperCase());
    await db.saveSetting(
        'shop_upi', _upiCtrl.text.trim());

    // Save custom QR settings
    if (_customQrBase64 != null &&
        _customQrBase64!.isNotEmpty) {
      await db.saveSetting(
          'shop_custom_qr', _customQrBase64!);
    }
    await db.saveSetting(
        'shop_use_custom_qr', _useCustomQr.toString());

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

  String? _validateGSTIN(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final gstin = v.trim().toUpperCase();
    final gstinRegex = RegExp(
        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    if (!gstinRegex.hasMatch(gstin)) {
      return 'Invalid GSTIN format (e.g. 27AAPFU0939F1ZV)';
    }
    return null;
  }

  String? _validateUPI(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!v.contains('@'))
      return 'Invalid UPI ID (e.g. name@upi)';
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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                : const Text('SAVE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Card(
                      color: AppColors.navy.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              color: AppColors.navy,
                              size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This info appears on your invoice PDF header.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _sectionTitle(
                        'Business Information', Icons.store),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shop / Business Name *',
                        hintText: 'e.g. Ram Vegetables',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      textCapitalization:
                          TextCapitalization.words,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Shop name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        hintText:
                            'Shop address, city, pincode',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.location_on),
                      ),
                      maxLines: 3,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Address is required'
                              : null,
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
                        FilteringTextInputFormatter
                            .digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Phone is required';
                        if (v.trim().length != 10)
                          return 'Enter 10-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(
                        'Tax & Payment', Icons.receipt_long),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (optional)',
                        hintText: 'e.g. 27AAPFU0939F1ZV',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.receipt_long),
                      ),
                      textCapitalization:
                          TextCapitalization.characters,
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
                            'Used to auto-generate QR on invoices',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: _validateUPI,
                      autovalidateMode:
                          AutovalidateMode.onUserInteraction,
                    ),
                    const SizedBox(height: 20),

                    // ── QR CODE SECTION ───────────────────────
                    _sectionTitle(
                        'Payment QR Code', Icons.qr_code_2),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload your own UPI/Bank QR code or use auto-generated QR from your UPI ID.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // QR type toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          // Toggle between auto and custom
                          Row(children: [
                            Expanded(
                              child: _QrOptionTile(
                                icon: Icons.auto_awesome,
                                title: 'Auto-Generate QR',
                                subtitle:
                                    'From your UPI ID above',
                                selected: !_useCustomQr,
                                color: AppColors.navy,
                                onTap: () => setState(
                                    () => _useCustomQr =
                                        false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QrOptionTile(
                                icon: Icons.upload_file,
                                title: 'Custom QR',
                                subtitle:
                                    'Upload your own image',
                                selected: _useCustomQr,
                                color: Colors.orange,
                                onTap: () => setState(
                                    () => _useCustomQr =
                                        true),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),

                          // Auto QR preview
                          if (!_useCustomQr) ...[
                            if (_upiCtrl.text
                                    .trim()
                                    .isNotEmpty &&
                                _upiCtrl.text.contains('@'))
                              Column(children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green
                                        .shade50,
                                    borderRadius:
                                        BorderRadius.circular(
                                            8),
                                    border: Border.all(
                                        color: Colors
                                            .green.shade200),
                                  ),
                                  child: Row(children: [
                                    const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'QR will be auto-generated for: ${_upiCtrl.text.trim()}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.green),
                                      ),
                                    ),
                                  ]),
                                ),
                              ])
                            else
                              Container(
                                padding:
                                    const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.orange.shade50,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors
                                          .orange.shade200),
                                ),
                                child: Row(children: [
                                  const Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Enter your UPI ID above to enable auto QR generation',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.orange),
                                    ),
                                  ),
                                ]),
                              ),
                          ],

                          // Custom QR upload
                          if (_useCustomQr) ...[
                            if (_customQrBase64 != null &&
                                _customQrBase64!
                                    .isNotEmpty) ...[
                              // Preview uploaded QR
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.green
                                          .shade300,
                                      width: 2),
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                                padding:
                                    const EdgeInsets.all(8),
                                child: Column(children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(
                                            8),
                                    child: Image.memory(
                                      base64Decode(
                                          _customQrBase64!),
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(
                                            Icons.edit,
                                            size: 16),
                                        label: const Text(
                                            'Change'),
                                        onPressed:
                                            _pickQrImage,
                                      ),
                                      const SizedBox(
                                          width: 8),
                                      TextButton.icon(
                                        icon: const Icon(
                                            Icons.delete,
                                            size: 16,
                                            color:
                                                Colors.red),
                                        label: const Text(
                                            'Remove',
                                            style: TextStyle(
                                                color: Colors
                                                    .red)),
                                        onPressed:
                                            _removeCustomQr,
                                      ),
                                    ],
                                  ),
                                ]),
                              ),
                            ] else ...[
                              // Upload button
                              GestureDetector(
                                onTap: _pickQrImage,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.all(
                                          24),
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .shade50,
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    border: Border.all(
                                      color: Colors
                                          .orange.shade300,
                                      width: 2,
                                      // Dashed border simulation
                                    ),
                                  ),
                                  child: Column(children: [
                                    Icon(Icons.upload_file,
                                        size: 48,
                                        color: Colors
                                            .orange.shade400),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap to upload your QR code',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'JPG, PNG supported\nFrom gallery or camera',
                                      textAlign:
                                          TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                    ),
                                  ]),
                                ),
                              ),
                            ],
                          ],
                        ]),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text(
                            'Save Shop Profile',
                            style:
                                TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.navy)),
        ],
      );
}

class _QrOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _QrOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color:
                    selected ? color : Colors.grey,
                size: 24),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: selected
                        ? color
                        : Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey)),
          ]),
        ),
      );
}
