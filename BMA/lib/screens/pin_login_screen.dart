import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../main.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({Key? key}) : super(key: key);
  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  String? _error;
  bool _loading = false;
  List<StaffUser> _staff = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final list =
        await context.read<AppDatabase>().getAllStaff();
    if (mounted) setState(() => _staff = list);
  }

  String _hashPin(String pin) {
    var hash = 0;
    for (final c in pin.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<void> _onKeyTap(String key) async {
    if (key == 'del') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _error = null;
        });
      }
      return;
    }

    if (_pin.length >= 4) return;
    final newPin = _pin + key;
    setState(() { _pin = newPin; _error = null; });

    if (newPin.length == 4) {
      await _verifyPin(newPin);
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _loading = true);
    final hashed = _hashPin(pin);

    // Check against all active staff
    final match = _staff.firstWhere(
      (s) => s.pin == hashed && s.isActive,
      orElse: () => _staff.first, // placeholder
    );

    final isValid = _staff.any(
        (s) => s.pin == hashed && s.isActive);

    if (isValid) {
      // Save logged-in staff to prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_staff_id', match.id);
      await prefs.setString('logged_in_staff_name', match.name);
      await prefs.setString('logged_in_staff_role', match.role);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const MainNavigation()),
        );
      }
    } else {
      setState(() {
        _pin = '';
        _error = 'Wrong PIN. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App logo/name
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.store,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 16),
                const Text('VyapaarX',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Enter your PIN to continue',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? Colors.green.shade700
                            : Colors.grey.shade300,
                        border: Border.all(
                          color: filled
                              ? Colors.green.shade700
                              : Colors.grey.shade400,
                        ),
                      ),
                    );
                  }),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 13)),
                ],

                const SizedBox(height: 32),

                // Number pad
                if (_loading)
                  const CircularProgressIndicator()
                else
                  Column(children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', 'del'],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: row.map((k) {
                            if (k.isEmpty) {
                              return const SizedBox(width: 80, height: 56);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              child: SizedBox(
                                width: 72,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: k == 'del'
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade100,
                                    foregroundColor: k == 'del'
                                        ? Colors.red
                                        : Colors.black87,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () =>
                                      _onKeyTap(k),
                                  child: k == 'del'
                                      ? const Icon(
                                          Icons.backspace_outlined,
                                          size: 20)
                                      : Text(k,
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight:
                                                  FontWeight.w500)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ]),

                if (_staff.isEmpty) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MainNavigation()),
                    ),
                    child: const Text('Skip (No staff set up yet)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
