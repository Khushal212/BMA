import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/app_database.dart';
import 'screens/dashboard_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/items_screen.dart';
import 'screens/new_invoice_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/shop_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final langCode = prefs.getString('language_code') ?? 'en';
  final isDark = prefs.getBool('dark_mode') ?? false;
  final db = AppDatabase();
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider(
            create: (_) => LocaleProvider(langCode)),
        ChangeNotifierProvider(
            create: (_) => ThemeProvider(isDark)),
      ],
      child: const MyApp(),
    ),
  );
}

class LocaleProvider extends ChangeNotifier {
  Locale _locale;
  LocaleProvider(String code) : _locale = Locale(code);
  Locale get locale => _locale;
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    notifyListeners();
  }
}

class ThemeProvider extends ChangeNotifier {
  bool _isDark;
  ThemeProvider(this._isDark);
  bool get isDark => _isDark;
  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDark);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    final tp = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'VyapaarX',
      debugShowCheckedModeBanner: false,
      locale: lp.locale,
      supportedLocales: AppLanguages.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: tp.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  static void jumpTo(BuildContext context, int index) {
    context
        .findAncestorStateOfType<_MainNavigationState>()
        ?.jumpTo(index);
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  void jumpTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();

    final screens = [
      const DashboardScreen(),
      const CustomersScreen(),
      const ItemsScreen(),
      const NewInvoiceScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green.shade600,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), label: 'Items'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Invoice'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: tp.isDark
                    ? Colors.green.shade900
                    : Colors.green.shade700,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 8),
                  const Text('VyapaarX',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Text('Smart Business Management',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

            // Dark mode
            SwitchListTile(
              secondary: Icon(
                tp.isDark ? Icons.dark_mode : Icons.light_mode,
                color: Colors.green.shade600,
              ),
              title: const Text('Dark Mode'),
              value: tp.isDark,
              activeColor: Colors.green.shade600,
              onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
            ),
            const Divider(),

            // Shop Profile
            ListTile(
              leading: Icon(Icons.store,
                  color: Colors.green.shade700),
              title: const Text('Shop Profile'),
              subtitle: const Text('Name, address, GSTIN, UPI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ShopProfileScreen()));
              },
            ),

            // Reports
            ListTile(
              leading: Icon(Icons.bar_chart,
                  color: Colors.purple.shade600),
              title: const Text('Reports'),
              subtitle: const Text('Monthly, weekly, customer'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ReportsScreen()));
              },
            ),

            // Stock
            ListTile(
              leading: Icon(Icons.inventory,
                  color: Colors.orange.shade600),
              title: const Text('Stock Management'),
              subtitle: const Text('Track inventory levels'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const StockScreen()));
              },
            ),

            // Backup
            ListTile(
              leading: Icon(Icons.backup,
                  color: Colors.blue.shade600),
              title: const Text('Backup & Restore'),
              subtitle: const Text('Save & restore your data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const BackupScreen()));
              },
            ),

            // Language
            ListTile(
              leading: Icon(Icons.language,
                  color: Colors.green.shade600),
              title: const Text('Language / भाषा'),
              subtitle: Text(AppLanguages.names[
                      context.read<LocaleProvider>().locale.languageCode] ??
                  'English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SettingsScreen()));
              },
            ),

            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('VyapaarX'),
              subtitle: Text('Version 1.0.0'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLanguages {
  static const List<Locale> supported = [
    Locale('en'), Locale('hi'), Locale('mr'), Locale('gu'),
    Locale('ta'), Locale('te'), Locale('bn'), Locale('kn'),
    Locale('ml'), Locale('pa'), Locale('or'), Locale('ur'),
    Locale('as'),
  ];
  static const Map<String, String> names = {
    'en': 'English', 'hi': 'हिंदी (Hindi)',
    'mr': 'मराठी (Marathi)', 'gu': 'ગુજરાતી (Gujarati)',
    'ta': 'தமிழ் (Tamil)', 'te': 'తెలుగు (Telugu)',
    'bn': 'বাংলা (Bengali)', 'kn': 'ಕನ್ನಡ (Kannada)',
    'ml': 'മലയാളം (Malayalam)', 'pa': 'ਪੰਜਾਬੀ (Punjabi)',
    'or': 'ଓଡ଼ିଆ (Odia)', 'ur': 'اردو (Urdu)',
    'as': 'অসমীয়া (Assamese)',
  };
}
