import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
import 'screens/staff_screen.dart';
import 'screens/sync_screen.dart';
import 'screens/settings_screen.dart';

class AppColors {
  static const navy      = Color(0xFF1B2A4A);
  static const navyDark  = Color(0xFF0D1B2A);
  static const navyLight = Color(0xFF2A3F6F);
  static const gold      = Color(0xFFF0A500);
  static const accent    = Color(0xFF4A90D9);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF5F7FA);
  static const success   = Color(0xFF2ECC71);
  static const danger    = Color(0xFFE74C3C);
  static const warning   = Color(0xFFF39C12);
}

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs    = await SharedPreferences.getInstance();
  final langCode = prefs.getString('language_code') ?? 'en';
  final isDark   = prefs.getBool('dark_mode') ?? false;
  final db       = AppDatabase();
  runApp(MultiProvider(
    providers: [
      Provider<AppDatabase>.value(value: db),
      ChangeNotifierProvider(create: (_) => LocaleProvider(langCode)),
      ChangeNotifierProvider(create: (_) => ThemeProvider(isDark)),
      ChangeNotifierProvider(create: (_) => ShopProfileProvider(db)),
    ],
    child: const MyApp(),
  ));
}

// ── Shop Profile Provider ──────────────────────────────────────
// Tracks whether the shop profile is complete.
// Any screen can read isComplete and react accordingly.
class ShopProfileProvider extends ChangeNotifier {
  final AppDatabase _db;
  bool _isComplete = false;
  bool _isLoading  = true;

  ShopProfileProvider(this._db) {
    _check();
  }

  bool get isComplete => _isComplete;
  bool get isLoading  => _isLoading;

  // Required fields: shop name, address, phone
  Future<void> _check() async {
    _isLoading = true;
    notifyListeners();
    final name    = (await _db.getSetting('shop_name'))    ?? '';
    final address = (await _db.getSetting('shop_address')) ?? '';
    final phone   = (await _db.getSetting('shop_phone'))   ?? '';
    _isComplete = name.trim().isNotEmpty &&
                  address.trim().isNotEmpty &&
                  phone.trim().isNotEmpty;
    _isLoading = false;
    notifyListeners();
  }

  // Call this after the user saves the shop profile
  Future<void> refresh() => _check();
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
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: tp.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildLightTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.offWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.white,
      centerTitle: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: AppColors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navy,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 3,
      shadowColor: AppColors.navy.withOpacity(0.15),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      color: AppColors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.navy, width: 2),
      ),
    ),
    floatingActionButtonTheme:
        const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
    ),
  );

  ThemeData _buildDarkTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navyLight,
      secondary: AppColors.gold,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navyDark,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navyDark,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1A2340),
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ── Splash Screen ──────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl, _logoCtrl, _textCtrl;
  late Animation<double> _bgOp, _logoScale, _logoOp, _textOp;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _bgCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bgOp      = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _bgCtrl,   curve: Curves.easeIn));
    _logoScale = Tween<double>(begin: 0.3, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOp    = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoCtrl,  curve: const Interval(0, 0.5, curve: Curves.easeIn)));
    _textOp    = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textCtrl,  curve: Curves.easeIn));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _bgCtrl.forward().then((_) =>
        _logoCtrl.forward().then((_) =>
            _textCtrl.forward().then((_) =>
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) {
                    Navigator.pushReplacement(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const MainNavigation(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 600),
                    ));
                  }
                }))));
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _logoCtrl.dispose(); _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navyDark.withOpacity(_bgOp.value),
              AppColors.navy.withOpacity(_bgOp.value),
              AppColors.navyLight.withOpacity(_bgOp.value),
            ],
          ),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Transform.scale(
                scale: _logoScale.value,
                child: Opacity(
                  opacity: _logoOp.value,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.store,
                        size: 60, color: AppColors.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => SlideTransition(
                position: _textSlide,
                child: Opacity(
                  opacity: _textOp.value,
                  child: Column(children: [
                    const Text('VyapaarX',
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('Smart Business Management',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            letterSpacing: 1)),
                    const SizedBox(height: 32),
                    _LoadingDots(),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;
  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600)));
    _anims = _ctrls.map((c) => Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }
  @override
  void dispose() { for (final c in _ctrls) c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (i) => AnimatedBuilder(
      animation: _anims[i],
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 8,
        height: 8 + (_anims[i].value * 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.4 + _anims[i].value * 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    )),
  );
}

// ── Main Navigation ────────────────────────────────────────────
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  static void jumpTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainNavigationState>()?.jumpTo(index);

  static void openDrawer(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavigationState>()?.openDrawer();

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeInOut);
    _pageCtrl.forward();
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  void jumpTo(int index) {
    // Block navigation if shop profile is incomplete (except index 0 = dashboard)
    if (index != 0 && !context.read<ShopProfileProvider>().isComplete) {
      _showProfileIncompleteDialog();
      return;
    }
    _pageCtrl.reverse().then((_) {
      setState(() => _selectedIndex = index);
      _pageCtrl.forward();
    });
  }

  void openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _onTabTap(int i) {
    if (i == _selectedIndex) return;
    // Block all tabs except Dashboard (0) if profile incomplete
    if (i != 0 && !context.read<ShopProfileProvider>().isComplete) {
      _showProfileIncompleteDialog();
      return;
    }
    _pageCtrl.reverse().then((_) {
      setState(() => _selectedIndex = i);
      _pageCtrl.forward();
    });
  }

  void _showProfileIncompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_outlined,
                color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Shop profile required',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: const Text(
          'Please complete your shop profile before using the app.\n\n'
          'You need to fill in:\n'
          '  • Shop name\n'
          '  • Address\n'
          '  • Phone number\n\n'
          'This information appears on your invoices.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Set up now'),
            onPressed: () {
              Navigator.pop(ctx);
              // Open shop profile screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopProfileScreen(
                    onSaved: () {
                      // Refresh provider so the gate re-evaluates
                      context.read<ShopProfileProvider>().refresh();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp      = context.watch<ThemeProvider>();
    final l       = context.l10n;
    final profile = context.watch<ShopProfileProvider>();

    final screens = [
      const DashboardScreen(),
      const CustomersScreen(),
      const ItemsScreen(),
      const NewInvoiceScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.25,
      drawerEnableOpenDragGesture: true,
      body: Stack(children: [
        FadeTransition(
          opacity: _pageFade,
          child: screens[_selectedIndex],
        ),
        // Profile incomplete banner — shown on dashboard only
        if (!profile.isLoading && !profile.isComplete && _selectedIndex == 0)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _ProfileIncompleteBanner(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopProfileScreen(
                    onSaved: () =>
                        context.read<ShopProfileProvider>().refresh(),
                  ),
                ),
              ),
            ),
          ),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.navyDark.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTap,
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                activeIcon: const Icon(Icons.dashboard),
                label: l.dashboard),
            BottomNavigationBarItem(
                icon: _lockedIcon(Icons.people_outline, profile.isComplete),
                activeIcon: const Icon(Icons.people),
                label: l.customers),
            BottomNavigationBarItem(
                icon: _lockedIcon(Icons.inventory_2_outlined, profile.isComplete),
                activeIcon: const Icon(Icons.inventory_2),
                label: l.items),
            BottomNavigationBarItem(
                icon: _lockedIcon(Icons.receipt_long_outlined, profile.isComplete),
                activeIcon: const Icon(Icons.receipt_long),
                label: l.invoice),
            BottomNavigationBarItem(
                icon: _lockedIcon(Icons.history_outlined, profile.isComplete),
                activeIcon: const Icon(Icons.history),
                label: l.history),
          ],
        ),
      ),
      drawer: _buildDrawer(tp, l, profile.isComplete),
    );
  }

  // Shows a lock badge on the icon when profile is incomplete
  Widget _lockedIcon(IconData icon, bool unlocked) {
    if (unlocked) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4, right: -6,
          child: Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.warning),
            child: const Icon(Icons.lock, size: 7, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(ThemeProvider tp, AppLocalizations l, bool profileComplete) =>
      Drawer(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navyDark, AppColors.navyLight],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gold.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.store, color: AppColors.gold, size: 30),
              ),
              const SizedBox(height: 12),
              Text(l.appTitle,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              Text(l.appSubtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12)),
              // Profile incomplete warning in drawer header
              if (!profileComplete) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber,
                        color: AppColors.warning, size: 14),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Shop profile incomplete',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SwitchListTile(
                  secondary: Icon(
                      tp.isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppColors.navy),
                  title: Text(l.darkMode),
                  value: tp.isDark,
                  activeColor: AppColors.navy,
                  onChanged: (_) =>
                      context.read<ThemeProvider>().toggleTheme(),
                ),
                const Divider(height: 1),
                // Shop profile always accessible — highlighted when incomplete
                _drawerItem(
                  icon: Icons.store,
                  label: l.shopProfile,
                  subtitle: profileComplete
                      ? l.upiHelperText
                      : 'Tap to complete setup',
                  color: profileComplete ? AppColors.navy : AppColors.warning,
                  badge: !profileComplete,
                  onTap: () => _navigate(ShopProfileScreen(
                    onSaved: () =>
                        context.read<ShopProfileProvider>().refresh(),
                  )),
                ),
                const Divider(height: 1),
                _drawerItem(
                  icon: Icons.group,
                  label: l.staffManagement,
                  subtitle: l.addStaff,
                  color: Colors.indigo,
                  locked: !profileComplete,
                  onTap: () => profileComplete
                      ? _navigate(const StaffScreen())
                      : _showProfileIncompleteDialog(),
                ),
                _drawerItem(
                  icon: Icons.cloud_sync,
                  label: l.dataSync,
                  subtitle: l.backupToGoogleDrive,
                  color: Colors.blue,
                  locked: !profileComplete,
                  onTap: () => profileComplete
                      ? _navigate(const SyncScreen())
                      : _showProfileIncompleteDialog(),
                ),
                _drawerItem(
                  icon: Icons.bar_chart,
                  label: l.reports,
                  subtitle: '${l.monthlyReport}, ${l.weeklyReport}',
                  color: Colors.purple,
                  locked: !profileComplete,
                  onTap: () => profileComplete
                      ? _navigate(const ReportsScreen())
                      : _showProfileIncompleteDialog(),
                ),
                _drawerItem(
                  icon: Icons.inventory,
                  label: l.stockManagement,
                  subtitle: l.trackInventory,
                  color: Colors.orange,
                  locked: !profileComplete,
                  onTap: () => profileComplete
                      ? _navigate(const StockScreen())
                      : _showProfileIncompleteDialog(),
                ),
                _drawerItem(
                  icon: Icons.backup,
                  label: l.backupRestore,
                  subtitle: l.saveRestoreData,
                  color: Colors.teal,
                  locked: !profileComplete,
                  onTap: () => profileComplete
                      ? _navigate(const BackupScreen())
                      : _showProfileIncompleteDialog(),
                ),
                _drawerItem(
                  icon: Icons.language,
                  label: l.language,
                  subtitle: AppLanguages.names[
                          context.read<LocaleProvider>().locale.languageCode] ??
                      'English',
                  color: Colors.green,
                  onTap: () => _navigate(const SettingsScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.grey),
                  title: Text(l.appTitle,
                      style: const TextStyle(color: Colors.grey)),
                  subtitle: Text(l.version,
                      style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool locked = false,
    bool badge  = false,
  }) =>
      ListTile(
        leading: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(locked ? 0.05 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: locked ? Colors.grey : color, size: 20),
          ),
          if (badge || locked)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: locked ? Colors.grey.shade400 : AppColors.warning,
                ),
                child: Icon(
                  locked ? Icons.lock : Icons.warning,
                  size: 8, color: Colors.white,
                ),
              ),
            ),
        ]),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: locked ? Colors.grey : null)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 11,
                color: badge ? AppColors.warning : null)),
        trailing: const Icon(Icons.chevron_right,
            color: Colors.grey, size: 18),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );

  void _navigate(Widget screen) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => screen));
}

// ── Profile incomplete banner ──────────────────────────────────
class _ProfileIncompleteBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileIncompleteBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.warning.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.store_outlined, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Complete your shop profile',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text('Name, address & phone required to use features',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Set up',
              style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ]),
    ),
  );
}

class AppLanguages {
  static const Map<String, String> names = {
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'mr': 'मराठी (Marathi)',
    'gu': 'ગુજરાતી (Gujarati)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'bn': 'বাংলা (Bengali)',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'ml': 'മലയാളം (Malayalam)',
    'pa': 'ਪੰਜਾਬੀ (Punjabi)',
    'or': 'ଓଡ଼ିଆ (Odia)',
    'ur': 'اردو (Urdu)',
    'as': 'অসমীয়া (Assamese)',
  };
}
