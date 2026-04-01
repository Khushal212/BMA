import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Customers, Items, Invoices, InvoiceLines, Payments, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── CUSTOMERS ─────────────────────────────────────────────────
  Future<void> createCustomer({
    required String id,
    required String name,
    required String phone,
    String? address,
    double creditLimit = 10000,
    double? defaultPricePercent,
    double defaultGstPercent = 0,
  }) =>
      into(customers).insert(CustomersCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        creditLimit: Value(creditLimit),
        defaultPricePercent: Value(defaultPricePercent),
        defaultGstPercent: Value(defaultGstPercent),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<Customer>> getAllCustomers() =>
      select(customers).get();

  Future<Customer?> getCustomer(String id) =>
      (select(customers)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateCustomer(Customer customer) =>
      update(customers).replace(customer);

  Future<void> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  // ── ITEMS ─────────────────────────────────────────────────────
  Future<void> createItem({
    required String id,
    required String name,
    required String unit,
    double? defaultRate,
    double gstPercent = 0,
  }) =>
      into(items).insert(ItemsCompanion(
        id: Value(id),
        name: Value(name),
        unit: Value(unit),
        defaultRate: Value(defaultRate),
        gstPercent: Value(gstPercent),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<Item>> getAllItems() => select(items).get();

  Future<Item?> getItem(String id) =>
      (select(items)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateItem(Item item) =>
      update(items).replace(item);

  Future<void> deleteItem(String id) =>
      (delete(items)..where((i) => i.id.equals(id))).go();

  // ── INVOICES ──────────────────────────────────────────────────
  Future<void> createInvoice({
    required String id,
    required String invoiceNo,
    required String customerId,
    required List<InvoiceLineData> lines,
    required double subtotal,
    double discountPercent = 0,
    double discountAmount = 0,
    required double gstAmount,
    double roundOff = 0,
    required double total,
    double paidAmount = 0,
    required double balanceAmount,
    required String paymentType,
    String? notes,
    String? pdfPath,
  }) async {
    await into(invoices).insert(InvoicesCompanion(
      id: Value(id),
      invoiceNo: Value(invoiceNo),
      customerId: Value(customerId),
      invoiceDate: Value(DateTime.now().millisecondsSinceEpoch),
      subtotal: Value(subtotal),
      discountPercent: Value(discountPercent),
      discountAmount: Value(discountAmount),
      gstAmount: Value(gstAmount),
      roundOff: Value(roundOff),
      total: Value(total),
      paidAmount: Value(paidAmount),
      balanceAmount: Value(balanceAmount),
      paymentType: Value(paymentType),
      notes: Value(notes),
      pdfPath: Value(pdfPath),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));

    for (final line in lines) {
      await into(invoiceLines).insert(InvoiceLinesCompanion(
        id: Value(line.id),
        invoiceId: Value(id),
        itemId: Value(line.itemId),
        itemNameSnapshot: Value(line.itemName),
        qty: Value(line.qty),
        unit: Value(line.unit),
        rate: Value(line.rate),
        lineSubtotal: Value(line.lineSubtotal),
        lineGstPercent: Value(line.lineGstPercent),
        lineGstAmount: Value(line.lineGstAmount),
        lineTotal: Value(line.lineTotal),
      ));
    }
  }

  Future<Invoice?> getInvoice(String id) =>
      (select(invoices)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<List<Invoice>> getAllInvoices() =>
      select(invoices).get();

  Future<List<Invoice>> getCustomerInvoices(String customerId) =>
      (select(invoices)
            ..where((i) => i.customerId.equals(customerId))
            ..orderBy([(i) => OrderingTerm(
                expression: i.invoiceDate,
                mode: OrderingMode.desc)]))
          .get();

  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) =>
      (select(invoiceLines)
            ..where((l) => l.invoiceId.equals(invoiceId)))
          .get();

  // ── PAYMENTS ──────────────────────────────────────────────────
  Future<void> recordPayment({
    required String id,
    required String customerId,
    required double amount,
    required String mode,
    String? reference,
    String? notes,
  }) =>
      into(payments).insert(PaymentsCompanion(
        id: Value(id),
        customerId: Value(customerId),
        paymentDate: Value(DateTime.now().millisecondsSinceEpoch),
        amount: Value(amount),
        mode: Value(mode),
        reference: Value(reference),
        notes: Value(notes),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<Payment>> getCustomerPayments(String customerId) =>
      (select(payments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm(
                expression: p.paymentDate,
                mode: OrderingMode.desc)]))
          .get();

  // ── BUSINESS LOGIC ────────────────────────────────────────────
  Future<double> getCustomerOutstanding(String customerId) async {
    final invRows = await (select(invoices)
          ..where((i) => i.customerId.equals(customerId)))
        .get();
    final payRows = await (select(payments)
          ..where((p) => p.customerId.equals(customerId)))
        .get();
    final totalBalance = invRows.fold<double>(
        0.0, (s, inv) => s + inv.balanceAmount);
    final totalPaid = payRows.fold<double>(
        0.0, (s, pay) => s + pay.amount);
    return (totalBalance - totalPaid).clamp(0.0, double.infinity);
  }

  Future<double> getTodaysSalesTotal() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59)
            .millisecondsSinceEpoch;
    final result = await (select(invoices)
          ..where(
              (i) => i.invoiceDate.isBetweenValues(start, end)))
        .get();
    return result.fold<double>(0.0, (s, inv) => s + inv.total);
  }

  Future<double> getTotalOutstanding() async {
    double total = 0;
    for (final c in await getAllCustomers()) {
      total += await getCustomerOutstanding(c.id);
    }
    return total;
  }

  Future<List<Customer>> getExceededCreditLimitCustomers() async {
    final exceeded = <Customer>[];
    for (final c in await getAllCustomers()) {
      if (await getCustomerOutstanding(c.id) > c.creditLimit) {
        exceeded.add(c);
      }
    }
    return exceeded;
  }

  Future<String> generateInvoiceNo() async {
    final now = DateTime.now();
    final prefix =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}-';
    final count = (await getAllInvoices())
            .where((inv) => inv.invoiceNo.startsWith(prefix))
            .length +
        1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  // ── SETTINGS ──────────────────────────────────────────────────
  Future<void> saveSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(value)));

  Future<String?> getSetting(String key) async {
    final r = await (select(settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return r?.value;
  }
}

// ── HELPER DATA CLASS ──────────────────────────────────────────
class InvoiceLineData {
  final String id;
  final String itemId;
  final String itemName;
  final double qty;
  final String unit;
  final double rate;
  final double lineSubtotal;
  final double lineGstPercent;
  final double lineGstAmount;
  final double lineTotal;

  InvoiceLineData({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.rate,
    required this.lineSubtotal,
    required this.lineGstPercent,
    required this.lineGstAmount,
    required this.lineTotal,
  });
}

// ── DATABASE CONNECTION ────────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bma.db'));
    return NativeDatabase.createInBackground(file);
  });
}
