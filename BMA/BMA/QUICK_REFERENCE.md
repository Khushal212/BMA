# BMA - Quick Reference Guide

## 🚀 Common Commands

### Initial Setup (First Time)
```bash
cd /Users/kalyanibadgujar/BMA
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Regular Development
```bash
flutter run                                    # Launch app
flutter run -d emulator-5554                   # Specific device
flutter run --debug                            # Debug mode
flutter run --release                          # Production build
```

### Database Code Generation
```bash
flutter pub run build_runner build             # Generate once
flutter pub run build_runner watch             # Watch for changes (auto-regenerate)
flutter pub run build_runner build --delete-conflicting-outputs  # Clean regenerate
```

### Troubleshooting
```bash
flutter clean                                  # Clean build artifacts
flutter pub get                                # Re-download packages
flutter doctor                                 # Check setup
flutter analyze                                # Check code quality
```

### Build APK (For Distribution)
```bash
flutter build apk --release                    # Build APK
flutter build appbundle --release              # Build for Play Store
```

---

## 📱 App Navigation

| Tab | Features |
|-----|----------|
| 🏠 Dashboard | Sales stats, alerts, credit limit exceeded customers |
| 👥 Customers | List, search, add, view detail + ledger |
| 📦 Items | Vegetables, add, edit, delete |
| 📋 Invoice | Create invoice, calculate totals, save |

### Screen Flow
```
Dashboard
├── View today's sales
├── View total outstanding
└── See credit limit alerts

Customers
├── Search customers
├── Tap customer → Customer Detail
│   ├── View outstanding
│   ├── Record payment
│   └── View all invoices
└── FAB → Add customer

Items
├── Search items
├── Long press → Edit/Delete
└── FAB → Add item

Invoice
├── Select customer
│   ├── Shows outstanding
│   └── Shows credit limit
├── Add items (FAB on each line)
├── Set discount %
├── Set payment type
└── Generate → Save
```

---

## 💾 Database Operations

### Customer Operations
```dart
// Create
await db.createCustomer(
  id: const Uuid().v4(),
  name: "John",
  phone: "9876543210",
  creditLimit: 50000,
  defaultGstPercent: 5,
);

// Read
final customer = await db.getCustomer(customerId);
final allCustomers = await db.getAllCustomers();

// Update
await db.updateCustomer(customer.copyWith(creditLimit: 60000));

// Delete
await db.deleteCustomer(customerId);

// Get outstanding
double outstanding = await db.getCustomerOutstanding(customerId);
```

### Item Operations
```dart
// Create
await db.createItem(
  id: const Uuid().v4(),
  name: "Tomato",
  unit: "kg",
  defaultRate: 50,
  gstPercent: 0,
);

// Read/Update/Delete
// (Similar to customers above)
```

### Invoice Operations
```dart
// Create
await db.createInvoice(
  id: invoiceId,
  invoiceNo: "INV-202601-0042",
  customerId: customerId,
  lines: [...],
  subtotal: 500,
  discountAmount: 0,
  gstAmount: 90,
  total: 590,
  paymentType: "CASH",
);

// Get invoices
final invoices = await db.getCustomerInvoices(customerId);
final invoice = await db.getInvoice(invoiceId);
```

### Payment Operations
```dart
// Record payment
await db.recordPayment(
  id: const Uuid().v4(),
  customerId: customerId,
  amount: 500,
  mode: "CASH",
  reference: "txn12345",
);

// Get payments
final payments = await db.getCustomerPayments(customerId);
```

---

## 🧮 Key Formulas

### Outstanding Balance
```
Outstanding = SUM(Invoice Balance Amounts) - SUM(Payment Amounts)

Invoice Balance Amount = {
  if paymentType = "CREDIT":   balanceAmount = total
  if paymentType = "CASH/UPI": balanceAmount = max(0, total - paidAmount)
}
```

### Invoice Totals
```
Subtotal = SUM(qty × rate)

Discount Amount = Subtotal × (Discount % / 100)

After Discount = Subtotal - Discount Amount

GST Amount = After Discount × (GST % / 100)

Total = After Discount + GST Amount

Balance = {
  if CREDIT: Total
  else: max(0, Total - Paid Amount)
}
```

### Credit Limit Check
```
Current Outstanding = (See Outstanding Balance above)

Projected Outstanding = Current Outstanding + New Invoice Balance

Alert if: Projected Outstanding > Customer Credit Limit
```

---

## 🎨 UI Components

### Common Widgets Used
```dart
// Navigation
BottomNavigationBar
MainNavigation (custom)

// Dialogs
AlertDialog
showDialog()
showModalBottomSheet()

// Data Display
FutureBuilder           // For async data
ListView.builder        // For lists
Card                    // For sections
Container              // For styling

// Forms
TextField
DropdownButtonFormField
TextButton
ElevatedButton
```

### Adding a New Screen
```dart
// 1. Create screen file
// lib/screens/my_screen.dart
class MyScreen extends StatefulWidget {
  const MyScreen({Key? key}) : super(key: key);
  
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Screen')),
      body: Center(child: Text('Content')),
    );
  }
}

// 2. Add to navigation in main.dart
// In MainNavigation.screens list
```

---

## 📄 PDF Generation

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Generate PDF
final pdf = await InvoiceGenerator.generateInvoicePDF(
  invoiceNo: invoiceNo,
  customerName: customerName,
  lines: invoiceLines,
  subtotal: subtotal,
  // ... other fields
);

// Show print dialog (Android)
await Printing.layoutPdf(
  onLayout: (PdfPageFormat format) async => pdf.save(),
);
```

---

## 🔄 Common Workflows

### Create Invoice Workflow
1. Tap Invoice tab
2. Select customer (shows outstanding + limit)
3. Click "Add Item"
4. Select item from list
5. Enter qty & rate
6. Repeat steps 3-5 for more items
7. Adjust discount % if needed
8. Select payment type
9. If CASH/UPI/BANK, enter paid amount
10. Click "Generate Invoice"
11. Confirm dialog appears

### Record Payment Workflow
1. Tap Customers tab
2. Tap customer name
3. Click "Record Payment"
4. Enter amount
5. Select mode (CASH/UPI/BANK)
6. (Optional) Enter reference
7. Click "Record"
8. Outstanding updates automatically

### Check Credit Limit Status
1. Tap Dashboard
2. Scroll to "Alerts" section
3. Green card = All OK
4. Red card = Customer(s) exceeded
5. Tap customer to see detail

---

## 🐛 Debugging Tips

### Print Logs
```dart
print('Value: $value');
print('Outstanding: ${await db.getCustomerOutstanding(id)}');
```

### Check Database State
```dart
// In any screen
final customers = await db.getAllCustomers();
print('Customers: $customers');

final invoices = await db.select(db.invoices).get();
print('All invoices: $invoices');
```

### Widget Rebuilds
```dart
// Wrap build() with this to see rebuilds
@override
Widget build(BuildContext context) {
  print('Building MyWidget'); // Prints on every rebuild
  return ...
}
```

### Error Catching
```dart
try {
  await db.createInvoice(...);
} catch (e) {
  print('Error: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

---

## 📦 File Locations

| What | Where |
|-----|-------|
| App Code | `/Users/kalyanibadgujar/BMA/lib/` |
| Android Config | `/Users/kalyanibadgujar/BMA/android/` |
| Database | `~/.local/share/bma/bma.db` (Android) |
| Generated Code | `/Users/kalyanibadgujar/BMA/lib/database/app_database.g.dart` |
| Build Artifacts | `/Users/kalyanibadgujar/BMA/build/` |
| Dependencies | `/Users/kalyanibadgujar/BMA/.dart_tool/` |

---

## 🔧 Configuration Changes

### Change App Name
```yaml
# pubspec.yaml
name: bma
description: "Business Management App"
```

### Change Theme Color
```dart
// lib/main.dart
theme: ThemeData(
  primarySwatch: Colors.green,  // Change here
  useMaterial3: true,
)
```

### Change Default Credit Limit
```dart
// lib/database/tables.dart
RealColumn get creditLimit => real().withDefault(const Constant(50000))();
```

### Change Invoice Format
```dart
// lib/utils/invoice_generator.dart
// Modify PDF layout in generateInvoicePDF()
```

---

## 💡 Pro Tips

1. **Save Time**: Use search in Customers/Items before adding duplicates
2. **Error Prevention**: Always check customer credit before invoice
3. **Data Backup**: Regularly export/backup database (future feature)
4. **Performance**: For 1000+ invoices, consider pagination
5. **Mobile**: Test on real device, not just emulator

---

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| App won't run | `flutter clean` → `flutter pub get` → `flutter run` |
| Database errors | `flutter pub run build_runner build --delete-conflicting-outputs` |
| Stuck on loading | Check device storage, restart emulator |
| UI not updating | Verify `setState()` called or FutureBuilder used |
| Invoice not saving | Check customer is selected, items added |

---

## 📚 Documentation Map

- **README.md** → Feature overview & usage guide
- **SETUP.md** → Installation & first launch
- **DEVELOPMENT.md** → Architecture & code structure
- **PROJECT_CHECKLIST.md** → What's included & status
- **This file** → Quick reference for common tasks

---

## ✅ Pre-Launch Checklist

- [ ] Flutter installed (`flutter --version`)
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Database code generated (`flutter pub run build_runner build`)
- [ ] App runs (`flutter run`)
- [ ] Create test customer
- [ ] Create test item
- [ ] Create test invoice
- [ ] Verify outstanding calculated correctly
- [ ] Record test payment
- [ ] Verify ledger updated

---

**Ready to build your business app?** 🚀

Next: Run `flutter pub get` and `flutter run`
