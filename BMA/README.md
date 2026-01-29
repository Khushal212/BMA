# BMA - Business Management App
## Vegetable Wholesaler Offline Invoice & Ledger System

A complete Flutter app for managing customer invoices, ledger tracking, credit limits, and payments with **offline-first SQLite database**.

---

## Features

✅ **Customer Management**
- Add/edit customers with credit limits
- Default GST and pricing rules per customer
- Search customers by name/phone

✅ **Item Management (Vegetables)**
- Add items with units (kg, crate, bunch, box)
- Default rates and GST per item
- Easy edit/delete interface

✅ **Invoice Generation**
- Select customer → add items → calculate totals
- Discount % and GST % customizable per invoice
- Payment types: Cash, UPI, Bank, Credit, Mixed
- Auto-generated invoice numbers (INV-YYYYMM-XXXX)

✅ **Customer Ledger**
- View all invoices per customer
- Outstanding balance calculation
- Payment history

✅ **Credit Limit Alerts**
- Real-time warning if invoice exceeds credit limit
- Dashboard alert for customers exceeding limit
- Optional block or allow override

✅ **PDF Invoice Generation**
- Professional invoice PDF with all details
- Item breakup, totals, GST calculation
- Ready to print or share

✅ **WhatsApp Share**
- Share invoice via WhatsApp (local PDF share method)
- Ready for upgrade to WhatsApp Business API

✅ **Dashboard**
- Today's sales total
- Total outstanding balance
- Credit limit exceeded alerts
- Quick action buttons

✅ **Offline-First**
- All data stored in SQLite locally
- Works without internet
- Optional cloud sync later

---

## Project Structure

```
lib/
├── main.dart                      # App entry point & navigation
├── database/
│   ├── app_database.dart          # Database operations (Drift)
│   ├── tables.dart                # Table definitions
│   └── app_database.g.dart        # Generated code (run build_runner)
├── models/
│   ├── customer.dart              # Customer model
│   ├── item.dart                  # Item model
│   ├── invoice.dart               # Invoice model
│   └── payment.dart               # Payment model
├── screens/
│   ├── dashboard_screen.dart      # Dashboard with stats & alerts
│   ├── customers_screen.dart      # Customer list, add, search
│   ├── customer_detail_screen.dart # Customer history & ledger
│   ├── items_screen.dart          # Item list, add, edit, delete
│   └── new_invoice_screen.dart    # Invoice creation flow
└── utils/
    └── invoice_generator.dart     # PDF generation
```

---

## Getting Started

### Prerequisites
- Flutter 3.4.0+
- Android SDK (for Android build)
- Dart 3.4.0+

### Installation & Setup

1. **Clone/open project in VS Code**
   ```bash
   cd /Users/kalyanibadgujar/BMA
   code .
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Drift database code** (IMPORTANT)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## Database Schema

### Customers
- `id` (UUID primary key)
- `name`, `phone`, `address`
- `creditLimit` (default: ₹10,000)
- `defaultPricePercent`, `defaultGstPercent`
- `createdAt`

### Items
- `id` (UUID)
- `name`, `unit` (kg/crate/bunch/box)
- `defaultRate`, `gstPercent` (default: 0%)
- `createdAt`

### Invoices
- `id`, `invoiceNo` (unique)
- `customerId`, `invoiceDate`
- `subtotal`, `discountPercent`, `discountAmount`
- `gstAmount`, `total`, `paidAmount`, `balanceAmount`
- `paymentType` (CASH/UPI/BANK/CREDIT/MIXED)
- `createdAt`, `pdfPath`

### InvoiceLines
- `id`, `invoiceId`, `itemId`
- `itemNameSnapshot`, `qty`, `unit`, `rate`
- `lineSubtotal`, `lineGstPercent`, `lineGstAmount`, `lineTotal`

### Payments
- `id`, `customerId`, `paymentDate`
- `amount`, `mode` (CASH/UPI/BANK)
- `reference` (optional), `notes`
- `createdAt`

---

## Usage Walkthrough

### Create First Invoice
1. Go to **Invoice** tab
2. Select customer (shows outstanding + credit limit)
3. Click "Add Item" → choose item → enter qty & rate
4. Set discount % (optional) and payment type
5. Click "Generate Invoice" → saved automatically
6. Share via WhatsApp (later feature)

### View Customer Ledger
1. Go to **Customers** tab
2. Tap on a customer
3. See outstanding balance, all invoices, payment history
4. Click "Record Payment" to log any payment

### Monitor Credit Limits
1. Go to **Dashboard**
2. "Total Outstanding" card shows total due
3. Alert section shows customers exceeding limit
4. Red warning when creating invoices over limit

---

## Key Business Rules

- **Outstanding = Sum(Invoice Balances) - Sum(Payments Received)**
- **Credit Limit Check**: On save, checks if `outstanding + new invoice balance > credit limit`
- **Invoice Numbering**: `INV-YYYYMM-XXXXX` (auto-resets monthly)
- **GST Calculation**: Default 18% unless overridden per invoice/item
- **Payment Types**: 
  - Cash/UPI/Bank → paid immediately, balance = 0
  - Credit → balance = total amount
  - Mixed → user enters paid amount

---

## Future Enhancements

1. **Cloud Sync** (Firebase)
   - Backup data to cloud
   - Multi-device access
   - Real-time sync

2. **WhatsApp Business API**
   - Auto-send invoices
   - Template messages
   - Payment reminders

3. **Advanced Reports**
   - Sales by date, customer, item
   - GST breakdown
   - Aging analysis
   - Profit/loss

4. **Inventory Tracking**
   - Stock levels per item
   - Low stock alerts
   - Purchase orders

5. **Multi-User & Branches**
   - Staff login
   - Role-based access
   - Multiple shops

---

## Troubleshooting

### Build issues?
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database issues?
- Delete app & reinstall: `flutter clean` → `flutter run`
- Database file location: `$HOME/Library/Application Support/your-app/bma.db`

### PDF not generating?
- Ensure `pdf` and `printing` packages are installed
- Run `flutter pub get` again

---

## Technology Stack

- **Framework**: Flutter 3.4.0+
- **Database**: SQLite + Drift ORM
- **State Management**: Provider
- **PDF**: pdf + printing packages
- **Sharing**: share_plus
- **Date/Time**: intl
- **ID Generation**: uuid

---

## License

This is a private business app. Use at your own discretion.

---

## Support

For issues or features, reach out directly.

---

**Ready to use offline!** 🚀 All data stays on your phone. No internet required for basic operations.
