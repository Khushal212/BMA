import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Customers, Items, Invoices, InvoiceLines,
    Payments, Settings, StockMovements
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
            items, items.currentStock);
        await migrator.addColumn(
            items, items.lowStockAlert);
        await migrator.createTable(stockMovements);
      }
    },
  );

  // ── CUSTOMERS ─────────────────────────────────────────────────
  Future<void> createCustomer({
    required String id, required String name,
    required String phone, String? address,
    double creditLimit = 10000,
    double? defaultPricePercent,
    double defaultGstPercent = 0,
  }) => into(customers).insert(CustomersCompanion(
        id: Value(id), name: Value(name),
        phone: Value(phone), address: Value(address),
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
  Future<void> updateCustomer(Customer c) =>
      update(customers).replace(c);
  Future<void> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  // ── ITEMS + STOCK ──────────────────────────────────────────────
  Future<void> createItem({
    required String id, required String name,
    required String unit, double? defaultRate,
    double gstPercent = 0,
    double currentStock = 0, double lowStockAlert = 10,
  }) => into(items).insert(ItemsCompanion(
        id: Value(id), name: Value(name), unit: Value(unit),
        defaultRate: Value(defaultRate),
        gstPercent: Value(gstPercent),
        currentStock: Value(currentStock),
        lowStockAlert: Value(lowStockAlert),
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

  Future<void> addStock({
    required String itemId,
    required double quantity,
    required String type,
    String? referenceId,
    String? notes,
  }) async {
    await (update(items)..where((i) => i.id.equals(itemId)))
        .write(ItemsCompanion(
      currentStock: Value(
          (await getItem(itemId))!.currentStock + quantity),
    ));
    await into(stockMovements).insert(StockMovementsCompanion(
      id: Value(DateTime.now().millisecondsSinceEpoch.toString()),
      itemId: Value(itemId),
      quantity: Value(quantity),
      type: Value(type),
      referenceId: Value(referenceId),
      notes: Value(notes),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<List<Item>> getLowStockItems() async {
    final allItems = await getAllItems();
    return allItems
        .where((i) => i.currentStock <= i.lowStockAlert)
        .toList();
  }

  // ── INVOICES ──────────────────────────────────────────────────
  Future<void> createInvoice({
    required String id, required String invoiceNo,
    required String customerId,
    required List<InvoiceLineData> lines,
    required double subtotal,
    double discountPercent = 0, double discountAmount = 0,
    required double gstAmount, double roundOff = 0,
    required double total, double paidAmount = 0,
    required double balanceAmount,
    required String paymentType,
    String? notes, String? pdfPath,
  }) async {
    await into(invoices).insert(InvoicesCompanion(
      id: Value(id), invoiceNo: Value(invoiceNo),
      customerId: Value(customerId),
      invoiceDate: Value(DateTime.now().millisecondsSinceEpoch),
      subtotal: Value(subtotal),
      discountPercent: Value(discountPercent),
      discountAmount: Value(discountAmount),
      gstAmount: Value(gstAmount), roundOff: Value(roundOff),
      total: Value(total), paidAmount: Value(paidAmount),
      balanceAmount: Value(balanceAmount),
      paymentType: Value(paymentType),
      notes: Value(notes), pdfPath: Value(pdfPath),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));

    for (final line in lines) {
      await into(invoiceLines).insert(InvoiceLinesCompanion(
        id: Value(line.id), invoiceId: Value(id),
        itemId: Value(line.itemId),
        itemNameSnapshot: Value(line.itemName),
        qty: Value(line.qty), unit: Value(line.unit),
        rate: Value(line.rate),
        lineSubtotal: Value(line.lineSubtotal),
        lineGstPercent: Value(line.lineGstPercent),
        lineGstAmount: Value(line.lineGstAmount),
        lineTotal: Value(line.lineTotal),
      ));
      // Auto-deduct stock
      final item = await getItem(line.itemId);
      if (item != null && item.currentStock > 0) {
        await addStock(
          itemId: line.itemId,
          quantity: -line.qty,
          type: 'INVOICE',
          referenceId: id,
          notes: 'Auto-deducted for invoice $invoiceNo',
        );
      }
    }
  }

  Future<Invoice?> getInvoice(String id) =>
      (select(invoices)..where((i) => i.id.equals(id)))
          .getSingleOrNull();
  Future<List<Invoice>> getAllInvoices() =>
      select(invoices).get();
  Future<List<Invoice>> getCustomerInvoices(String cId) =>
      (select(invoices)
            ..where((i) => i.customerId.equals(cId))
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
    required String id, required String customerId,
    required double amount, required String mode,
    String? reference, String? notes,
  }) => into(payments).insert(PaymentsCompanion(
        id: Value(id), customerId: Value(customerId),
        paymentDate: Value(DateTime.now().millisecondsSinceEpoch),
        amount: Value(amount), mode: Value(mode),
        reference: Value(reference), notes: Value(notes),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<Payment>> getCustomerPayments(String cId) =>
      (select(payments)
            ..where((p) => p.customerId.equals(cId))
            ..orderBy([(p) => OrderingTerm(
                expression: p.paymentDate,
                mode: OrderingMode.desc)]))
          .get();

  // ── BUSINESS LOGIC ────────────────────────────────────────────
  Future<double> getCustomerOutstanding(String cId) async {
    final invRows = await (select(invoices)
          ..where((i) => i.customerId.equals(cId)))
        .get();
    final payRows = await (select(payments)
          ..where((p) => p.customerId.equals(cId)))
        .get();
    final bal = invRows.fold<double>(
        0.0, (s, i) => s + i.balanceAmount);
    final paid = payRows.fold<double>(
        0.0, (s, p) => s + p.amount);
    return (bal - paid).clamp(0.0, double.infinity);
  }

  Future<double> getTodaysSalesTotal() async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day)
            .millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day, 23, 59, 59)
            .millisecondsSinceEpoch;
    final r = await (select(invoices)
          ..where(
              (i) => i.invoiceDate.isBetweenValues(start, end)))
        .get();
    return r.fold<double>(0.0, (s, i) => s + i.total);
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
            .where((i) => i.invoiceNo.startsWith(prefix))
            .length + 1;
    return '$prefix${count.toString().padLeft(5, '0')}';
  }

  // ── CUSTOMER REPORT ───────────────────────────────────────────
  Future<CustomerReport> getCustomerReport(String customerId) async {
    final customer = await getCustomer(customerId);
    final invList = await getCustomerInvoices(customerId);
    final payList = await getCustomerPayments(customerId);
    final outstanding = await getCustomerOutstanding(customerId);

    final totalBusiness =
        invList.fold<double>(0.0, (s, i) => s + i.total);
    final totalPaid =
        payList.fold<double>(0.0, (s, p) => s + p.amount);

    // Item-wise purchase breakdown
    final itemMap = <String, ItemPurchaseSummary>{};
    for (final inv in invList) {
      final lines = await getInvoiceLines(inv.id);
      for (final l in lines) {
        itemMap.update(
          l.itemNameSnapshot,
          (e) => ItemPurchaseSummary(
            itemName: e.itemName,
            totalQty: e.totalQty + l.qty,
            totalAmount: e.totalAmount + l.lineTotal,
            unit: l.unit,
          ),
          ifAbsent: () => ItemPurchaseSummary(
            itemName: l.itemNameSnapshot,
            totalQty: l.qty,
            totalAmount: l.lineTotal,
            unit: l.unit,
          ),
        );
      }
    }

    return CustomerReport(
      customer: customer!,
      totalInvoices: invList.length,
      totalBusiness: totalBusiness,
      totalPaid: totalPaid,
      outstanding: outstanding,
      invoices: invList,
      payments: payList,
      itemBreakdown: itemMap.values.toList()
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount)),
    );
  }

  // ── MONTHLY/WEEKLY SUMMARY ────────────────────────────────────
  Future<PeriodSummary> getMonthlySummary(int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 0, 23, 59, 59)
        .millisecondsSinceEpoch;
    return _getPeriodSummary(start, end);
  }

  Future<PeriodSummary> getWeeklySummary(DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month,
            weekStart.day)
        .millisecondsSinceEpoch;
    final end = DateTime(weekStart.year, weekStart.month,
            weekStart.day + 6, 23, 59, 59)
        .millisecondsSinceEpoch;
    return _getPeriodSummary(start, end);
  }

  Future<PeriodSummary> _getPeriodSummary(
      int start, int end) async {
    final periodInvoices = await (select(invoices)
          ..where(
              (i) => i.invoiceDate.isBetweenValues(start, end)))
        .get();
    final totalSales =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.total);
    final totalCollected =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.paidAmount);
    final totalPending =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.balanceAmount);

    // Day-wise breakdown
    final dayMap = <String, double>{};
    for (final inv in periodInvoices) {
      final day = DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate);
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      dayMap[key] = (dayMap[key] ?? 0) + inv.total;
    }

    return PeriodSummary(
      totalSales: totalSales,
      totalCollected: totalCollected,
      totalPending: totalPending,
      invoiceCount: periodInvoices.length,
      dayWiseSales: dayMap,
    );
  }

  // ── DAILY SUMMARY ─────────────────────────────────────────────
  Future<DailySummary> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
    final end =
        DateTime(date.year, date.month, date.day, 23, 59, 59)
            .millisecondsSinceEpoch;
    final dayInvoices = await (select(invoices)
          ..where(
              (i) => i.invoiceDate.isBetweenValues(start, end))
          ..orderBy([(i) => OrderingTerm(
              expression: i.invoiceDate,
              mode: OrderingMode.desc)]))
        .get();

    final result = <DailyInvoiceDetail>[];
    for (final inv in dayInvoices) {
      final customer = await getCustomer(inv.customerId);
      final lines = await getInvoiceLines(inv.id);
      result.add(DailyInvoiceDetail(
        id: inv.id, invoiceNo: inv.invoiceNo,
        invoiceDate: inv.invoiceDate,
        customerName: customer?.name ?? 'Unknown',
        total: inv.total, paidAmount: inv.paidAmount,
        balanceAmount: inv.balanceAmount,
        subtotal: inv.subtotal,
        discountAmount: inv.discountAmount,
        gstAmount: inv.gstAmount, lines: lines,
      ));
    }
    return DailySummary(
      totalSales: result.fold(0.0, (s, i) => s + i.total),
      collected: result.fold(0.0, (s, i) => s + i.paidAmount),
      pending: result.fold(0.0, (s, i) => s + i.balanceAmount),
      invoices: result,
    );
  }

  // ── ALL INVOICES WITH CUSTOMER ────────────────────────────────
  Future<List<InvoiceWithCustomer>>
      getAllInvoicesWithCustomers() async {
    final allInvoices = await (select(invoices)
          ..orderBy([(i) => OrderingTerm(
              expression: i.invoiceDate,
              mode: OrderingMode.desc)]))
        .get();
    final result = <InvoiceWithCustomer>[];
    for (final inv in allInvoices) {
      final customer = await getCustomer(inv.customerId);
      result.add(InvoiceWithCustomer(
        id: inv.id, invoiceNo: inv.invoiceNo,
        invoiceDate: inv.invoiceDate,
        customerName: customer?.name ?? 'Unknown',
        total: inv.total, paidAmount: inv.paidAmount,
        balanceAmount: inv.balanceAmount,
        subtotal: inv.subtotal,
        discountAmount: inv.discountAmount,
        gstAmount: inv.gstAmount,
      ));
    }
    return result;
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

// ── DATA CLASSES ──────────────────────────────────────────────
class InvoiceLineData {
  final String id, itemId, itemName, unit;
  final double qty, rate, lineSubtotal, lineGstPercent,
      lineGstAmount, lineTotal;
  InvoiceLineData({
    required this.id, required this.itemId,
    required this.itemName, required this.qty,
    required this.unit, required this.rate,
    required this.lineSubtotal, required this.lineGstPercent,
    required this.lineGstAmount, required this.lineTotal,
  });
}

class DailySummary {
  final double totalSales, collected, pending;
  final List<DailyInvoiceDetail> invoices;
  DailySummary({required this.totalSales,
      required this.collected, required this.pending,
      required this.invoices});
}

class DailyInvoiceDetail {
  final String id, invoiceNo, customerName;
  final int invoiceDate;
  final double total, paidAmount, balanceAmount,
      subtotal, discountAmount, gstAmount;
  final List<InvoiceLine> lines;
  DailyInvoiceDetail({
    required this.id, required this.invoiceNo,
    required this.invoiceDate, required this.customerName,
    required this.total, required this.paidAmount,
    required this.balanceAmount, required this.subtotal,
    required this.discountAmount, required this.gstAmount,
    required this.lines,
  });
}

class InvoiceWithCustomer {
  final String id, invoiceNo, customerName;
  final int invoiceDate;
  final double total, paidAmount, balanceAmount,
      subtotal, discountAmount, gstAmount;
  InvoiceWithCustomer({
    required this.id, required this.invoiceNo,
    required this.invoiceDate, required this.customerName,
    required this.total, required this.paidAmount,
    required this.balanceAmount, required this.subtotal,
    required this.discountAmount, required this.gstAmount,
  });
}

class CustomerReport {
  final Customer customer;
  final int totalInvoices;
  final double totalBusiness, totalPaid, outstanding;
  final List<Invoice> invoices;
  final List<Payment> payments;
  final List<ItemPurchaseSummary> itemBreakdown;
  CustomerReport({
    required this.customer, required this.totalInvoices,
    required this.totalBusiness, required this.totalPaid,
    required this.outstanding, required this.invoices,
    required this.payments, required this.itemBreakdown,
  });
}

class ItemPurchaseSummary {
  final String itemName, unit;
  final double totalQty, totalAmount;
  ItemPurchaseSummary({
    required this.itemName, required this.unit,
    required this.totalQty, required this.totalAmount,
  });
}

class PeriodSummary {
  final double totalSales, totalCollected, totalPending;
  final int invoiceCount;
  final Map<String, double> dayWiseSales;
  PeriodSummary({
    required this.totalSales, required this.totalCollected,
    required this.totalPending, required this.invoiceCount,
    required this.dayWiseSales,
  });
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bma.db'));
    return NativeDatabase.createInBackground(file);
  });
}
