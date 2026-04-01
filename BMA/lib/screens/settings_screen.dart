import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentCode =
        localeProvider.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings / सेटिंग्स'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.language,
                        color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    const Text('Select Language',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                      'भाषा चुनें / ভাষা নির্বাচন করুন / மொழி தேர்வு',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...AppLanguages.names.entries.map((e) {
                    final isSelected =
                        e.key == currentCode;
                    return InkWell(
                      onTap: () {
                        context
                            .read<LocaleProvider>()
                            .setLocale(Locale(e.key));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              'Language changed to ${e.value}'),
                          duration:
                              const Duration(seconds: 2),
                        ));
                      },
                      borderRadius:
                          BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(
                            bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade50
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green.shade400
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Text(_flagEmoji(e.key),
                              style: const TextStyle(
                                  fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.green.shade700
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                color:
                                    Colors.green.shade600,
                                size: 22),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text('About',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  _infoRow('App', 'BMA v1.0.0'),
                  _infoRow('For',
                      'Vegetable Wholesalers & Traders'),
                  _infoRow('Features',
                      'Customers, Items, Invoices, Payments'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  String _flagEmoji(String code) {
    const flags = {
      'en': '🇬🇧',
      'hi': '🇮🇳',
      'mr': '🇮🇳',
      'gu': '🇮🇳',
      'ta': '🇮🇳',
      'te': '🇮🇳',
      'bn': '🇮🇳',
      'kn': '🇮🇳',
      'ml': '🇮🇳',
      'pa': '🇮🇳',
      'or': '🇮🇳',
      'ur': '🇮🇳',
      'as': '🇮🇳',
    };
    return flags[code] ?? '🌐';
  }
}
