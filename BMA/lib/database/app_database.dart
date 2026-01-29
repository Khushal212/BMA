import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Customers,
    Items,
    Invoices,
    InvoiceLines,
    Payments,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // CUSTOMER OPERATIONS
  Future<void> createCustomer({
    required String id,
    required String name,
    required String phone,
    String? address,
    double creditLimit = 10000,
    double? defaultPricePercent,
    double defaultGstPercent = 0,
  }) {
    return into(customers).insert(
      CustomersCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        creditLimit: Value(creditLimit),
        defaultPricePercent: Value(defaultPricePercent),
        defaultGstPercent: Value(defaultGstPercent),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<Customer>> getAllCustomers() =>
      select(customers).get();

  Future<Customer?> getCustomer(String id) =>
      (select(customers)..where((c) => c.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateCustomer(Customer customer) =>
      update(customers).replace(customer);

  Future<void> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  // ITEM OPERATIONS
  Future<void> createItem({
    required String id,
    required String name,
    required String unit,
    double? defaultRate,
    double gstPercent = 0,
  }) {
    return into(items).insert(
      ItemsCompanion(
        id: Value(id),
        name: Value(name),
        unit: Value(unit),
        defaultRate: Value(defaultRate),
        gstPercent: Value(gstPercent),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<Item>> getAllItems() =>
      select(items).get();

  Future<Item?> getItem(String id) =>
      (select(items)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateItem(Item item) =>
      update(items).replace(item);

  Future<void> deleteItem(String id) =>
      (delete(items)..where((i) => i.id.equals(id))).go();

  // INVOICE OPERATIONS
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
    await into(invoices).insert(
      InvoicesCompanion(
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
      ),
    );

    // Insert invoice lines
    for (var line in lines) {
      await into(invoiceLines).insert(
        InvoiceLinesCompanion(
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
        ),
      );
    }
  }

  Future<Invoice?> getInvoice(String id) =>
      (select(invoices)..where((i) => i.id.equals(id)))
          .getSingleOrNull();

  Future<List<Invoice>> getCustomerInvoices(String customerId) =>
      (select(invoices)
            ..where((i) => i.customerId.equals(customerId))
            ..orderBy([(i) => OrderingTerm(expression: i.invoiceDate, mode: OrderingMode.desc)])
      ).get();

  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) =>
      (select(invoiceLines)..where((l) => l.invoiceId.equals(invoiceId)))
          .get();

  // PAYMENT OPERATIONS
  Future<void> recordPayment({
    required String id,
    required String customerId,
    required double amount,
    required String mode,
    String? reference,
    String? notes,
  }) {
    return into(payments).insert(
      PaymentsCompanion(
        id: Value(id),
        customerId: Value(customerId),
        paymentDate: Value(DateTime.now().millisecondsSinceEpoch),
        amount: Value(amount),
        mode: Value(mode),
        reference: Value(reference),
        notes: Value(notes),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<Payment>> getCustomerPayments(String customerId) =>
      (select(payments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm(expression: p.paymentDate, mode: OrderingMode.desc)])
      ).get();

  // LEDGER CALCULATIONS
  Future<double> getCustomerOutstanding(String customerId) async {
    final invoices = await (select(invoices)
          ..where((i) => i.customerId.equals(customerId)))
        .get();

    final payments = await (select(payments)
          ..where((p) => p.customerId.equals(customerId)))
        .get();

    double totalInvoiceBalance = invoices.fold(0, (sum, inv) => sum + inv.balanceAmount);
    double totalPayments = payments.fold(0, (sum, pay) => sum + pay.amount);

    return totalInvoiceBalance - totalPayments;
  }

  // STATISTICS
  Future<double> getTodaysSalesTotal() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final result = await (select(invoices)
          ..where((i) => i.invoiceDate.isBetweenValues(startOfDay, endOfDay)))
        .get();

    return result.fold(0, (sum, inv) => sum + inv.total);
  }

  Future<double> getTotalOutstanding() async {
    final allCustomers = await getAllCustomers();
    double total = 0;

    for (var customer in allCustomers) {
      total += await getCustomerOutstanding(customer.id);
    }

    return total;
  }

  Future<List<Customer>> getExceededCreditLimitCustomers() async {
    final customers = await getAllCustomers();
    final exceeding = <Customer>[];

    for (var customer in customers) {
      final outstanding = await getCustomerOutstanding(customer.id);
      if (outstanding > customer.creditLimit) {
        exceeding.add(customer);
      }
    }

    return exceeding;
  }

  // SETTINGS
  Future<void> saveSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  Future<String?> getSetting(String key) async {
    final result = await (select(settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }
}

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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bma.db'));
    if (!kIsWeb && !file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    return NativeDatabase(file);
  });
}

const kIsWeb = false;
