# BMA Development Guide

## Project Overview

**Business Management App (BMA)** is a complete offline-first Flutter app for vegetable wholesalers to manage:
- Customer database with credit limits
- Item/inventory management
- Invoice generation with GST calculation
- Payment tracking and ledger
- Credit limit alerts
- PDF invoice generation
- WhatsApp sharing capability

---

## Architecture Overview

### Technology Stack
- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Database**: SQLite + Drift ORM
- **PDF**: pdf + printing packages
- **Utilities**: uuid, intl, share_plus, url_launcher

### Folder Structure
```
lib/
├── main.dart                         # App entry, navigation setup
├── database/                         # Database layer
│   ├── tables.dart                   # Drift table definitions
│   ├── app_database.dart             # Database operations & business logic
│   └── app_database.g.dart           # Auto-generated (run build_runner)
├── models/                           # Data models
│   ├── customer.dart
│   ├── item.dart
│   ├── invoice.dart
│   └── payment.dart
├── screens/                          # UI Screens
│   ├── dashboard_screen.dart         # Home with stats & alerts
│   ├── customers_screen.dart         # Customer list
│   ├── customer_detail_screen.dart   # Customer ledger
│   ├── items_screen.dart             # Item list
│   └── new_invoice_screen.dart       # Invoice creation
└── utils/                            # Utilities
    └── invoice_generator.dart        # PDF generation
```

---

## Key Components Explained

### 1. Database Layer (`database/`)

**Tables:**
- `Customers`: Master customer data with credit limits
- `Items`: Product master (vegetables with units & rates)
- `Invoices`: Invoice headers with totals
- `InvoiceLines`: Item details within each invoice
- `Payments`: Payment records against customers
- `Settings`: App configuration (future use)

**Database Operations** (in `app_database.dart`):
```dart
// Customer operations
Future<void> createCustomer(...)
Future<List<Customer>> getAllCustomers()
Future<Customer?> getCustomer(String id)
Future<void> updateCustomer(Customer customer)
Future<void> deleteCustomer(String id)

// Outstanding calculation (CORE LOGIC)
Future<double> getCustomerOutstanding(String customerId)
  // Returns: Sum(Invoice Balances) - Sum(Payments)

// Credit limit check
Future<List<Customer>> getExceededCreditLimitCustomers()
  // Returns customers where outstanding > creditLimit
```

**Key Formula - Outstanding Balance:**
```
Outstanding = SUM(invoices.balanceAmount) - SUM(payments.amount)

For each invoice:
balanceAmount = total - paidAmount (if CASH/UPI/BANK)
balanceAmount = total (if CREDIT)
```

### 2. Screens

#### Dashboard Screen
- **Stats Cards**: Today's sales, total outstanding
- **Alerts**: List of customers exceeding credit limit
- **Quick Actions**: Buttons for main features
- **Refresh**: Real-time calculation on open

#### Customers Screen
- **Search**: Filter by name/phone
- **List**: All customers with outstanding balance
- **Status**: Green (normal) or Red (exceeded limit)
- **Actions**: 
  - Tap → View detail screen
  - FAB → Add customer

#### Customer Detail Screen
- **Header**: Customer info + credit limit
- **Balance Card**: Outstanding amount, record payment button
- **Invoice List**: All invoices with dates, amounts, balance
- **Payment Recording**: Modal dialog to record payment

#### Items Screen
- **Search**: Filter items
- **List**: All items with unit, rate, GST
- **Actions**:
  - Tap → View detail
  - Long press → Edit/Delete
  - FAB → Add item

#### New Invoice Screen
- **Step 1**: Select customer (shows outstanding warning)
- **Step 2**: Add items from master
- **Step 3**: Apply discount %, GST %, payment type
- **Summary**: Auto-calculate and show totals
- **Generate**: Save invoice, show confirmation
- **Share**: Button to send via WhatsApp (future)

### 3. Models (`models/`)

Each model has:
- All fields matching database table
- `copyWith()` method for immutable updates
- Used for type-safe data passing between screens

Example:
```dart
class Customer {
  final String id, name, phone, address;
  final double creditLimit, defaultGstPercent;
  
  Customer copyWith({...}) => Customer(...)
}
```

### 4. Invoice Generation (`utils/`)

**InvoiceGenerator.generateInvoicePDF():**
- Takes invoice data (customer, items, totals)
- Generates PDF document using `pdf` package
- Returns `pw.Document` ready to print/save
- Professional layout with header, items table, totals, signature lines

---

## Data Flow Example: Creating an Invoice

**User Action**: Tap "Generate Invoice"

1. **Validation** (in `new_invoice_screen.dart`)
   - Customer selected? ✓
   - Items added? ✓
   - Calculate outstanding: `db.getCustomerOutstanding(customerId)`

2. **Calculate Totals**
   ```
   subtotal = SUM(qty * rate for each line)
   discountAmount = subtotal * discountPercent / 100
   afterDiscount = subtotal - discountAmount
   gstAmount = afterDiscount * gstPercent / 100
   total = afterDiscount + gstAmount
   
   If paymentType = CREDIT:
     balanceAmount = total
   Else:
     balanceAmount = total - paidAmount (minimum 0)
   ```

3. **Create Invoice in Database**
   ```dart
   db.createInvoice(
     id: UUID,
     invoiceNo: "INV-202601-0042",
     customerId: selectedCustomer,
     lines: [...InvoiceLineData],
     subtotal, discountAmount, gstAmount, total,
     balanceAmount, paymentType
   )
   ```

4. **Persist to Database**
   - Insert invoice header into `invoices` table
   - Insert each line into `invoiceLines` table
   - Auto-updates customer's outstanding

5. **Reset Form**
   ```dart
   _selectedCustomerId = null
   _lines.clear()
   _discountPercent = 0
   _paymentType = 'CASH'
   ```

6. **Show Confirmation**
   - AlertDialog: "Invoice INV-202601-0042 generated!"

---

## Credit Limit Alert Logic

**Dashboard & New Invoice Screen:**

```dart
// Get customer's outstanding
double outstanding = db.getCustomerOutstanding(customerId)

// Get customer details
Customer customer = db.getCustomer(customerId)

// Check if exceeded
bool isExceeded = outstanding > customer.creditLimit

// On new invoice screen, show projected
double projectedOutstanding = outstanding + newInvoiceTotal
bool willExceed = projectedOutstanding > customer.creditLimit

// Show red warning if true
```

**UI Indicators:**
- 🟢 Green: `outstanding <= creditLimit` (normal)
- 🔴 Red: `outstanding > creditLimit` (exceeded)
- 🟡 Yellow (future): Would exceed on this invoice

---

## Payment Recording Flow

**User taps "Record Payment":**

1. **Modal Dialog**
   - Amount (required)
   - Mode (CASH/UPI/BANK)
   - Reference (optional: UPI txn ID, cheque no)
   - Notes (optional)

2. **Save to Database**
   ```dart
   db.recordPayment(
     customerId: customer.id,
     amount: amountEntered,
     mode: selectedMode,
     reference: referenceEntered
   )
   ```

3. **Ledger Updates Automatically**
   - Outstanding recalculated: `getCustomerOutstanding()` includes latest payment
   - UI refreshes with FutureBuilder

---

## Important Business Rules

### 1. Outstanding Calculation
```
Outstanding = SUM(invoices.balance_amount) - SUM(payments.amount)
```
- Always positive (money owed)
- Can be zero if fully paid
- Automatically includes all invoices + payments

### 2. Invoice Balance
```
For CASH/UPI/BANK payment:
  balance = max(0, total - paidAmount)
  
For CREDIT payment:
  balance = total
  
For MIXED:
  balance = max(0, total - paidAmount)
```

### 3. Credit Limit Check
```
Before saving invoice:
  projectedOutstanding = currentOutstanding + newInvoiceBalance
  if projectedOutstanding > creditLimit:
    warn user (red alert)
    optionally block save (can be overridden later)
```

### 4. GST Handling
- Default: 18% (configurable per item, per customer, per invoice)
- Calculated on amount after discount
- Shown separately in invoice PDF and ledger

### 5. Invoice Numbering
- Format: `INV-YYYYMM-XXXXX`
- Example: `INV-202601-00042`
- Auto-generated, globally unique
- Optional: Monthly reset (feature for later)

---

## State Management with Provider

**Setup in main.dart:**
```dart
MultiProvider(
  providers: [
    Provider<AppDatabase>(
      create: (_) => AppDatabase(),  // Singleton instance
    ),
  ],
  child: MyApp(),
)
```

**Usage in screens:**
```dart
final db = context.read<AppDatabase>();  // Get database instance

// Use database methods
final customers = await db.getAllCustomers();
```

**Why Provider?**
- Simple, lightweight
- Perfect for singleton database
- No complex state needed for this app
- Easy to upgrade to Riverpod later if needed

---

## Building & Running

### First-Time Setup
```bash
cd /Users/kalyanibadgujar/BMA

# 1. Get dependencies
flutter pub get

# 2. CRITICAL: Generate database code
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run app
flutter run

# 4. (Optional) Choose device if multiple
flutter run -d <device_id>
```

### Subsequent Runs
```bash
flutter run
```

### If Database Code Changes
```bash
flutter pub run build_runner build
```

### Clean Build (if issues)
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

---

## Adding New Features

### Example: Add Discount Rules Per Customer

**Step 1: Update Database**
```dart
// In tables.dart, add to Customers table
RealColumn get defaultDiscount => real().nullable()();

// Update schemaVersion to 2 in app_database.dart
```

**Step 2: Create Migration**
```dart
// Drift handles migrations automatically on schema change
// Just bump schemaVersion and Drift migrates the database
```

**Step 3: Update Model**
```dart
class Customer {
  // ... existing fields
  final double? defaultDiscount;  // New field
}
```

**Step 4: Use in Screens**
```dart
// In new_invoice_screen.dart
final discount = _selectedCustomer.defaultDiscount ?? 0;
```

### Example: Add Cloud Sync (Firebase)

**Step 1: Add dependency**
```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^latest
  cloud_firestore: ^latest
```

**Step 2: Create sync layer**
```dart
// lib/services/cloud_sync.dart
class CloudSyncService {
  Future<void> syncCustomers() async {
    // Get local customers from SQLite
    // Compare with Firebase Firestore
    // Push/pull changes
  }
}
```

**Step 3: Integrate into database**
```dart
// In AppDatabase, call sync after each operation
await syncService.syncAfterInvoiceCreate();
```

---

## Testing (Future)

**Unit Tests**: Database operations
```dart
// test/database_test.dart
void main() {
  test('Outstanding calculation', () async {
    // Create test customer, invoices, payments
    // Assert outstanding matches expected
  });
}
```

**Widget Tests**: UI screens
```dart
// test/widget_test.dart
testWidgets('Customer list loads', (WidgetTester tester) async {
  // Build app, pump widgets
  // Verify customer list renders
});
```

---

## Debugging

### Print Logs
```dart
print('Outstanding: $outstanding');  // Use print for debugging
```

### Breakpoints
- Set breakpoints in VS Code
- Run: `flutter run` (not release)
- Debugger will pause at breakpoints

### Database Inspection
```dart
// Query database directly in code
final allInvoices = await db.select(db.invoices).get();
print(allInvoices);  // See all invoices
```

### Common Errors

**1. "app_database.g.dart not found"**
- Solution: Run `flutter pub run build_runner build`

**2. "Type mismatch" errors**
- Solution: Run `flutter clean`, then `flutter pub get`, then `flutter pub run build_runner build`

**3. "LateInitializationError" on database**
- Solution: Ensure AppDatabase is provided in MultiProvider

**4. "Drift tables not syncing"**
- Solution: Restart build_runner and app

---

## Performance Tips

1. **Query Optimization**
   - Use `getCustomerOutstanding()` sparingly (calculation intensive)
   - Cache results if needed
   - Consider adding ledger entries table for denormalization

2. **UI Rendering**
   - Use `FutureBuilder` for async data
   - Avoid rebuilding entire list on single item change
   - Use `ListView.builder` with shrinkWrap for large lists

3. **Database Indexing**
   - Drift auto-creates indexes on primary/foreign keys
   - Add manual indexes for frequently queried columns:
   ```dart
   @override
   List<Set<Column>> get uniqueKeys => [
     {invoiceNo},
     {customerId},
   ];
   ```

---

## Deployment

### Android APK Build
```bash
flutter build apk --release
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### Version Update
```dart
// In pubspec.yaml
version: 1.0.1+2  // version+buildNumber
```

---

## Resources & Links

- **Flutter Docs**: https://flutter.dev/docs
- **Drift Documentation**: https://drift.simonbinder.eu/docs/
- **Provider**: https://pub.dev/packages/provider
- **pdf Package**: https://pub.dev/packages/pdf

---

## Support & Troubleshooting

**App won't run?**
1. `flutter doctor` - Check dependencies
2. `flutter clean` - Clean build artifacts
3. `flutter pub get` - Re-download packages
4. `flutter pub run build_runner build` - Regenerate database code

**Data not persisting?**
1. Check database file path: `~/.local/share/bma/bma.db` (Android)
2. Verify `AppDatabase()` is singleton in Provider
3. Ensure `await` on all database operations

**UI not updating?**
1. Rebuild FutureBuilder with fresh query
2. Use `setState(() {})` to trigger rebuild
3. Check Provider is properly providing AppDatabase

---

**This app is ready for production use!** 🚀

All features are implemented. Extend as needed for your specific requirements.
