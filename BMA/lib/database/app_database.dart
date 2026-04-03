import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── TABLE DEFINITIONS ──────────────────────────────────────────

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get address => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(10000))();
  RealColumn get defaultPricePercent => real().nullable()();
  RealColumn get defaultGstPercent => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  RealColumn get defaultRate => real().nullable()();
  RealColumn get gstPercent => real().withDefault(const Constant(0))();
  RealColumn get currentStock => real().withDefault(const Constant(0))();
  RealColumn get lowStockAlert => real().withDefault(const Constant(10))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text()();
  TextColumn get customerId => text()();
  IntColumn get invoiceDate => integer()();
  RealColumn get subtotal => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get gstAmount => real()();
  RealColumn get roundOff => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get balanceAmount => real()();
  TextColumn get paymentType => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get pdfPath => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class InvoiceLines extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemNameSnapshot => text()();
  RealColumn get qty => real()();
  TextColumn get unit => text()();
  RealColumn get rate => real()();
  RealColumn get lineSubtotal => real()();
  RealColumn get lineGstPercent => real()();
  RealColumn get lineGstAmount => real()();
  RealColumn get lineTotal => real()();
  RealColumn get marginPercent => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  IntColumn get paymentDate => integer()();
  RealColumn get amount => real()();
  TextColumn get mode => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  RealColumn get quantity => real()();
  TextColumn get type => text()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class StaffUsers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get pin => text()();
  TextColumn get role => text()();
  BoolColumn get canCreateInvoice => boolean().withDefault(const Constant(true))();
  BoolColumn get canViewReports => boolean().withDefault(const Constant(false))();
  BoolColumn get canManageCustomers => boolean().withDefault(const Constant(true))();
  BoolColumn get canManageItems => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── RESULT CLASSES ─────────────────────────────────────────────

class InvoiceWithCustomer {
  final String id;
  final String invoiceNo;
  final String customerId;
  final String customerName;
  final int invoiceDate;
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double gstAmount;
  final double total;
  final double paidAmount;
  final double balanceAmount;
  final String paymentType;
  final String? notes;
  final String? createdBy;
  final int createdAt;
  final List<InvoiceLine> lines;

  InvoiceWithCustomer({
    required this.id,
    required this.invoiceNo,
    required this.customerId,
    required this.customerName,
    required this.invoiceDate,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.gstAmount,
    required this.total,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentType,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.lines = const [],
  });
}

class DailySummary {
  final double totalSales;
  final double collected;
  final double pending;
  final int invoiceCount;
  final List<InvoiceWithCustomer> invoices;

  DailySummary({
    required this.totalSales,
    required this.collected,
    required this.pending,
    required this.invoiceCount,
    required this.invoices,
  });
}

class PeriodSummary {
  final double totalSales;
  final double totalCollected;
  final double totalPending;
  final int invoiceCount;
  final double avgInvoiceValue;
  final Map<String, double> dayWiseSales;

  PeriodSummary({
    required this.totalSales,
    required this.totalCollected,
    required this.totalPending,
    required this.invoiceCount,
    required this.avgInvoiceValue,
    required this.dayWiseSales,
  });
}

class CustomerReport {
  final double totalBusiness;
  final double totalPaid;
  final double outstanding;
  final int totalInvoices;
  final List<Invoice> invoices;
  final List<Map<String, dynamic>> itemBreakdown;

  CustomerReport({
    required this.totalBusiness,
    required this.totalPaid,
    required this.outstanding,
    required this.totalInvoices,
    required this.invoices,
    required this.itemBreakdown,
  });
}

// ── DATABASE ───────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Customers, Items, Invoices, InvoiceLines,
    Payments, Settings, StockMovements, StaffUsers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(items, items.currentStock);
        await migrator.addColumn(items, items.lowStockAlert);
        await migrator.createTable(stockMovements);
      }
      if (from < 3) {
        await migrator.createTable(staffUsers);
        await migrator.addColumn(invoices, invoices.createdBy);
      }
    },
  );

  // ── CUSTOMERS ──────────────────────────────────────────────────
  Future<List<Customer>> getAllCustomers() => select(customers).get();

  Future<Customer?> getCustomer(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> createCustomer({
    required String id,
    required String name,
    required String phone,
    String? address,
    double creditLimit = 10000,
    double defaultGstPercent = 0,
  }) =>
      into(customers).insert(CustomersCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        creditLimit: Value(creditLimit),
        defaultGstPercent: Value(defaultGstPercent),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<void> updateCustomer(Customer c) =>
      (update(customers)..where((t) => t.id.equals(c.id))).write(
        CustomersCompanion(
          name: Value(c.name),
          phone: Value(c.phone),
          address: Value(c.address),
          creditLimit: Value(c.creditLimit),
          defaultGstPercent: Value(c.defaultGstPercent),
        ),
      );

  Future<void> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  Future<List<Customer>> getExceededCreditLimitCustomers() async {
    final all = await getAllCustomers();
    final result = <Customer>[];
    for (final c in all) {
      if (c.creditLimit <= 0) continue;
      final outstanding = await getCustomerOutstanding(c.id);
      if (outstanding > c.creditLimit) result.add(c);
    }
    return result;
  }

  // ── ITEMS ──────────────────────────────────────────────────────
  Future<List<Item>> getAllItems() => select(items).get();

  Future<Item?> getItem(String id) =>
      (select(items)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> createItem({
    required String id,
    required String name,
    required String unit,
    double? defaultRate,
    double gstPercent = 0,
    double currentStock = 0,
    double lowStockAlert = 10,
  }) =>
      into(items).insert(ItemsCompanion(
        id: Value(id),
        name: Value(name),
        unit: Value(unit),
        defaultRate: Value(defaultRate),
        gstPercent: Value(gstPercent),
        currentStock: Value(currentStock),
        lowStockAlert: Value(lowStockAlert),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<void> updateItem(ItemsCompanion item) =>
      (update(items)..where((i) => i.id.equals(item.id.value))).write(item);

  Future<void> deleteItem(String id) =>
      (delete(items)..where((i) => i.id.equals(id))).go();

  Future<void> addStock({
    required String itemId,
    required double quantity,
    required String type,
    String? notes,
  }) async {
    final item = await getItem(itemId);
    if (item == null) return;
    final delta = (type == 'WASTAGE') ? -quantity.abs() : quantity.abs();
    await (update(items)..where((i) => i.id.equals(itemId)))
        .write(ItemsCompanion(currentStock: Value(item.currentStock + delta)));
    await into(stockMovements).insert(StockMovementsCompanion(
      id: Value(DateTime.now().millisecondsSinceEpoch.toString()),
      itemId: Value(itemId),
      quantity: Value(delta),
      type: Value(type),
      notes: Value(notes),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  // ── INVOICES ───────────────────────────────────────────────────
  Future<List<Invoice>> getAllInvoices() => select(invoices).get();

  Future<Invoice?> getInvoice(String id) =>
      (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<String> generateInvoiceNo() async {
    final all = await select(invoices).get();
    final num = all.length + 1;
    return 'INV${num.toString().padLeft(4, '0')}';
  }

  Future<void> createInvoice({
    required String id,
    required String invoiceNo,
    required String customerId,
    required int invoiceDate,
    required double subtotal,
    double discountPercent = 0,
    required double discountAmount,
    required double gstAmount,
    required double total,
    required double paidAmount,
    required double balanceAmount,
    required String paymentType,
    String? notes,
    String? createdBy,
    required List<InvoiceLinesCompanion> lines,
  }) async {
    await into(invoices).insert(InvoicesCompanion(
      id: Value(id),
      invoiceNo: Value(invoiceNo),
      customerId: Value(customerId),
      invoiceDate: Value(invoiceDate),
      subtotal: Value(subtotal),
      discountPercent: Value(discountPercent),
      discountAmount: Value(discountAmount),
      gstAmount: Value(gstAmount),
      total: Value(total),
      paidAmount: Value(paidAmount),
      balanceAmount: Value(balanceAmount),
      paymentType: Value(paymentType),
      notes: Value(notes),
      createdBy: Value(createdBy),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    for (final line in lines) {
      await into(invoiceLines).insert(line);
      final item = await getItem(line.itemId.value);
      if (item != null) {
        await (update(items)..where((i) => i.id.equals(item.id))).write(
            ItemsCompanion(
                currentStock: Value(item.currentStock - line.qty.value)));
      }
    }
  }

  Future<List<InvoiceWithCustomer>> getAllInvoicesWithCustomers() async {
    final rows = await (select(invoices).join([
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ])
          ..orderBy([OrderingTerm.desc(invoices.invoiceDate)]))
        .get();

    final result = <InvoiceWithCustomer>[];
    for (final r in rows) {
      final inv = r.readTable(invoices);
      final cust = r.readTableOrNull(customers);
      final lines = await getInvoiceLines(inv.id);
      result.add(InvoiceWithCustomer(
        id: inv.id,
        invoiceNo: inv.invoiceNo,
        customerId: inv.customerId,
        customerName: cust?.name ?? 'Unknown',
        invoiceDate: inv.invoiceDate,
        subtotal: inv.subtotal,
        discountPercent: inv.discountPercent,
        discountAmount: inv.discountAmount,
        gstAmount: inv.gstAmount,
        total: inv.total,
        paidAmount: inv.paidAmount,
        balanceAmount: inv.balanceAmount,
        paymentType: inv.paymentType,
        notes: inv.notes,
        createdBy: inv.createdBy,
        createdAt: inv.createdAt,
        lines: lines,
      ));
    }
    return result;
  }

  Future<List<Invoice>> getCustomerInvoices(String customerId) =>
      (select(invoices)
            ..where((i) => i.customerId.equals(customerId))
            ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
          .get();

  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) =>
      (select(invoiceLines)..where((l) => l.invoiceId.equals(invoiceId))).get();

  // ── PAYMENTS ───────────────────────────────────────────────────
  Future<List<Payment>> getCustomerPayments(String customerId) =>
      (select(payments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm.desc(p.paymentDate)]))
          .get();

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

  Future<void> recordPartialPayment({
    required String id,
    required String customerId,
    required String invoiceId,
    required double amount,
    required String mode,
    String? reference,
    String? notes,
  }) async {
    await into(payments).insert(PaymentsCompanion(
      id: Value(id),
      customerId: Value(customerId),
      paymentDate: Value(DateTime.now().millisecondsSinceEpoch),
      amount: Value(amount),
      mode: Value(mode),
      reference: Value(reference),
      notes: Value(notes ?? 'Partial payment for invoice $invoiceId'),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    final inv = await getInvoice(invoiceId);
    if (inv != null) {
      final newBalance =
          (inv.balanceAmount - amount).clamp(0.0, double.infinity);
      final newPaid = inv.paidAmount + amount;
      await (update(invoices)..where((i) => i.id.equals(invoiceId)))
          .write(InvoicesCompanion(
        paidAmount: Value(newPaid),
        balanceAmount: Value(newBalance),
      ));
    }
  }

  Future<double> getCustomerOutstanding(String customerId) async {
    final invList = await getCustomerInvoices(customerId);
    return invList.fold<double>(0.0, (sum, i) => sum + i.balanceAmount);
  }

  Future<double> getTodaysSalesTotal() async {
    final s = await getDailySummary(DateTime.now());
    return s.totalSales;
  }

  Future<double> getTotalOutstanding() async {
    final all = await select(invoices).get();
    return all.fold<double>(0.0, (sum, i) => sum + i.balanceAmount);
  }

  // ── SETTINGS ───────────────────────────────────────────────────
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(value)));

  Future<void> saveSetting(String key, String value) => setSetting(key, value);

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  // ── REPORTS ────────────────────────────────────────────────────
  Future<DailySummary> getDailySummary(DateTime date) async {
    final start =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final dayInvoices = await (select(invoices)
          ..where((i) =>
              i.invoiceDate.isBiggerOrEqualValue(start) &
              i.invoiceDate.isSmallerOrEqualValue(end)))
        .get();
    final allWithCustomer = await getAllInvoicesWithCustomers();
    final dayWithCustomer = allWithCustomer
        .where((i) => i.invoiceDate >= start && i.invoiceDate <= end)
        .toList();
    return DailySummary(
      totalSales: dayInvoices.fold<double>(0.0, (s, i) => s + i.total),
      collected: dayInvoices.fold<double>(0.0, (s, i) => s + i.paidAmount),
      pending: dayInvoices.fold<double>(0.0, (s, i) => s + i.balanceAmount),
      invoiceCount: dayInvoices.length,
      invoices: dayWithCustomer,
    );
  }

  Future<PeriodSummary> getMonthlySummary(int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(seconds: 1))
        .millisecondsSinceEpoch;
    return _getPeriodSummary(start, end);
  }

  Future<PeriodSummary> getWeeklySummary(DateTime weekStart) async {
    final start =
        DateTime(weekStart.year, weekStart.month, weekStart.day)
            .millisecondsSinceEpoch;
    final end =
        DateTime(weekStart.year, weekStart.month, weekStart.day + 7)
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch;
    return _getPeriodSummary(start, end);
  }

  Future<PeriodSummary> _getPeriodSummary(int start, int end) async {
    final periodInvoices = await (select(invoices)
          ..where((i) =>
              i.invoiceDate.isBiggerOrEqualValue(start) &
              i.invoiceDate.isSmallerOrEqualValue(end)))
        .get();
    final totalSales =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.total);
    final totalCollected =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.paidAmount);
    final totalPending =
        periodInvoices.fold<double>(0.0, (s, i) => s + i.balanceAmount);
    final dayWiseSales = <String, double>{};
    for (final inv in periodInvoices) {
      final d = DateTime.fromMillisecondsSinceEpoch(inv.invoiceDate);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      dayWiseSales[key] = (dayWiseSales[key] ?? 0) + inv.total;
    }
    return PeriodSummary(
      totalSales: totalSales,
      totalCollected: totalCollected,
      totalPending: totalPending,
      invoiceCount: periodInvoices.length,
      avgInvoiceValue:
          periodInvoices.isEmpty ? 0 : totalSales / periodInvoices.length,
      dayWiseSales: dayWiseSales,
    );
  }

  Future<CustomerReport> getCustomerReport(String customerId) async {
    final invList = await getCustomerInvoices(customerId);
    final totalBusiness = invList.fold<double>(0.0, (s, i) => s + i.total);
    final totalPaid = invList.fold<double>(0.0, (s, i) => s + i.paidAmount);
    final outstanding =
        invList.fold<double>(0.0, (s, i) => s + i.balanceAmount);
    final itemTotals = <String, Map<String, dynamic>>{};
    for (final inv in invList) {
      final lines = await getInvoiceLines(inv.id);
      for (final l in lines) {
        if (!itemTotals.containsKey(l.itemId)) {
          itemTotals[l.itemId] = {
            'itemName': l.itemNameSnapshot,
            'totalQty': 0.0,
            'unit': l.unit,
            'totalAmount': 0.0,
          };
        }
        itemTotals[l.itemId]!['totalQty'] =
            (itemTotals[l.itemId]!['totalQty'] as double) + l.qty;
        itemTotals[l.itemId]!['totalAmount'] =
            (itemTotals[l.itemId]!['totalAmount'] as double) + l.lineTotal;
      }
    }
    return CustomerReport(
      totalBusiness: totalBusiness,
      totalPaid: totalPaid,
      outstanding: outstanding,
      totalInvoices: invList.length,
      invoices: invList,
      itemBreakdown: itemTotals.values.toList(),
    );
  }

  // ── BULK WHATSAPP ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingCustomersForReminder({
    int minDays = 7,
  }) async {
    final allCustomers = await getAllCustomers();
    final result = <Map<String, dynamic>>[];
    for (final c in allCustomers) {
      final outstanding = await getCustomerOutstanding(c.id);
      if (outstanding <= 0) continue;
      final invList = await getCustomerInvoices(c.id);
      final pendingInvoices =
          invList.where((i) => i.balanceAmount > 0).toList();
      if (pendingInvoices.isEmpty) continue;
      final lastInvoice = pendingInvoices.first;
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(
              lastInvoice.invoiceDate))
          .inDays;
      if (daysSince >= minDays) {
        result.add({
          'customer': c,
          'outstanding': outstanding,
          'daysSince': daysSince,
          'lastInvoiceNo': lastInvoice.invoiceNo,
          'lastInvoiceDate': lastInvoice.invoiceDate,
        });
      }
    }
    result.sort((a, b) =>
        (b['outstanding'] as double).compareTo(a['outstanding'] as double));
    return result;
  }

  // ── STAFF MANAGEMENT ──────────────────────────────────────────
  Future<void> createStaff({
    required String id,
    required String name,
    required String phone,
    required String pin,
    required String role,
    bool canCreateInvoice = true,
    bool canViewReports = false,
    bool canManageCustomers = true,
    bool canManageItems = false,
  }) =>
      into(staffUsers).insert(StaffUsersCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(phone),
        pin: Value(pin),
        role: Value(role),
        canCreateInvoice: Value(canCreateInvoice),
        canViewReports: Value(canViewReports),
        canManageCustomers: Value(canManageCustomers),
        canManageItems: Value(canManageItems),
        isActive: const Value(true),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<StaffUser>> getAllStaff() => select(staffUsers).get();

  Future<StaffUser?> getStaffById(String id) =>
      (select(staffUsers)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> updateStaff(StaffUser staff) =>
      update(staffUsers).replace(staff);

  Future<void> deleteStaff(String id) =>
      (delete(staffUsers)..where((s) => s.id.equals(id))).go();
}

// ── DB CONNECTION ──────────────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'arthaflow.db'));
    return NativeDatabase(file);
  });
}
