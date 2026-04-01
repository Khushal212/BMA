import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/app_database.dart';
import 'screens/dashboard_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/items_screen.dart';
import 'screens/new_invoice_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(
    Provider<AppDatabase>.value(
      value: db,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMA - Business Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2E7D32),
            side: const BorderSide(color: Color(0xFF2E7D32), width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    CustomersScreen(),
    ItemsScreen(),
    NewInvoiceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), label: 'Items'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Invoice'),
        ],
      ),
    );
  }
}
