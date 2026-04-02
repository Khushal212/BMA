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
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  RealColumn get defaultRate => real().withDefault(const Constant(0))();
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
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get gstAmount => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get balanceAmount => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
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
  TextColumn get unit => text()();
  RealColumn get qty => real()();
  RealColumn get rate => real()();
  RealColumn get lineGstPercent => real().withDefault(const Constant(0))();
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
  TextColumn get mode => text().withDefault(const Constant('Cash'))();
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
  TextColumn get type => text()(); // 'in' or 'out'
  RealColumn get qty => real()();
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
  TextColumn get role => text().withDefault(const Constant('staff'))();
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
  final double discountAmount;
  final double gstAmount;
  final double total;
  final double paidAmount;
  final double balanceAmount;
  final String? notes;
  final String? createdBy;
  final int createdAt;

  InvoiceWithCustomer({
    required this.id,
    required this.invoiceNo,
    required this.customerId,
    required this.customerName,
    required this.invoiceDate,
    required this.subtotal,
    required this.discountAmount,
    required this.gstAmount,
    required this.total,
    required this.paidAmount,
    required this.balanceAmount,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });
}

class DailySummary {
  final double totalSales;
  final double totalCollected;
  final int invoiceCount;
  final double totalPending;

  DailySummary({
    required this.totalSales,
    required this.totalCollected,
    required this.invoiceCount,
    required this.totalPending,
  });
}

class PeriodSummary {
  final double totalSales;
  final double totalCollected;
  final double totalPending;
  final int invoiceCount;
  final double avgInvoiceValue;

  PeriodSummary({
    required this.totalSales,
    required this.totalCollected,
    required this.totalPending,
    required this.invoiceCount,
    required this.avgInvoiceValue,
  });
}

class CustomerReport {
  final double totalBilled;
  final double totalPaid;
  final double totalPending;
  final int invoiceCount;
  final List<Invoice> invoices;

  CustomerReport({
    required this.totalBilled,
    required this.totalPaid,
    required this.totalPending,
    required this.invoiceCount,
    required this.invoices,
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

  Future<Customer?> getCustomerById(String id) =>
      (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> upsertCustomer(CustomersCompanion c) =>
      into(customers).insertOnConflictUpdate(c);

  Future<void> deleteCustomer(String id) =>
      (delete(customers)..where((c) => c.id.equals(id))).go();

  // ── ITEMS ──────────────────────────────────────────────────────
  Future<List<Item>> getAllItems() => select(items).get();

  Future<void> upsertItem(ItemsCompanion item) =>
      into(items).insertOnConflictUpdate(item);

  Future<void> deleteItem(String id) =>
      (delete(items)..where((i) => i.id.equals(id))).go();

  Future<void> updateItem(ItemsCompanion item) =>
      (update(items)..where((i) => i.id.equals(item.id.value))).write(item);

  Future<void> addStock(String itemId, double qty, String notes) async {
    final item = await (select(items)..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    await (update(items)..where((i) => i.id.equals(itemId)))
        .write(ItemsCompanion(currentStock: Value(item.currentStock + qty)));
    await into(stockMovements).insert(StockMovementsCompanion(
      id: Value(DateTime.now().millisecondsSinceEpoch.toString()),
      itemId: Value(itemId),
      type: const Value('in'),
      qty: Value(qty),
      notes: Value(notes),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  // ── INVOICES ───────────────────────────────────────────────────
  Future<Invoice?> getInvoice(String id) =>
      (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> createInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceLinesCompanion> lines,
  }) async {
    await into(invoices).insert(invoice);
    for (final line in lines) {
      await into(invoiceLines).insert(line);
      // Deduct stock
      final item = await (select(items)
            ..where((i) => i.id.equals(line.itemId.value)))
          .getSingleOrNull();
      if (item != null) {
        await (update(items)..where((i) => i.id.equals(item.id)))
            .write(ItemsCompanion(
                currentStock: Value(item.currentStock - line.qty.value)));
      }
    }
  }

  Future<List<InvoiceWithCustomer>> getAllInvoicesWithCustomer() async {
    final rows = await (select(invoices).join([
      leftOuterJoin(customers, customers.id.equalsExp(invoices.customerId)),
    ])
          ..orderBy([OrderingTerm.desc(invoices.invoiceDate)]))
        .get();
    return rows.map((r) {
      final inv = r.readTable(invoices);
      final cust = r.readTableOrNull(customers);
      return InvoiceWithCustomer(
        id: inv.id,
        invoiceNo: inv.invoiceNo,
        customerId: inv.customerId,
        customerName: cust?.name ?? 'Unknown',
        invoiceDate: inv.invoiceDate,
        subtotal: inv.subtotal,
        discountAmount: inv.discountAmount,
        gstAmount: inv.gstAmount,
        total: inv.total,
        paidAmount: inv.paidAmount,
        balanceAmount: inv.balanceAmount,
        notes: inv.notes,
        createdBy: inv.createdBy,
        createdAt: inv.createdAt,
      );
    }).toList();
  }

  Future<List<Invoice>> getCustomerInvoices(String customerId) =>
      (select(invoices)
            ..where((i) => i.customerId.equals(customerId))
            ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
          .get();

  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) =>
      (select(invoiceLines)..where((l) => l.invoiceId.equals(invoiceId))).get();

  Future<String> getNextInvoiceNo() async {
    final all = await select(invoices).get();
    final num = all.length + 1;
    return 'INV${num.toString().padLeft(4, '0')}';
  }

  // ── PAYMENTS ───────────────────────────────────────────────────
  Future<List<Payment>> getCustomerPayments(String customerId) =>
      (select(payments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm.desc(p.paymentDate)]))
          .get();

  Future<void> recordPayment(PaymentsCompanion payment) =>
      into(payments).insert(payment);

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

  Future<double> getInvoicePaidAmount(String invoiceId) async {
    final inv = await getInvoice(invoiceId);
    return inv?.paidAmount ?? 0;
  }

  Future<double> getCustomerOutstanding(String customerId) async {
    final invList = await getCustomerInvoices(customerId);
    return invList.fold(0.0, (sum, i) => sum + i.balanceAmount);
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

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  // ── REPORTS ────────────────────────────────────────────────────
  Future<DailySummary> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final dayInvoices = await (select(invoices)
          ..where((i) =>
              i.invoiceDate.isBiggerOrEqualValue(start) &
              i.invoiceDate.isSmallerOrEqualValue(end)))
        .get();
    final totalSales =
        dayInvoices.fold(0.0, (s, i) => s + i.total);
    final totalCollected =
        dayInvoices.fold(0.0, (s, i) => s + i.paidAmount);
    final totalPending =
        dayInvoices.fold(0.0, (s, i) => s + i.balanceAmount);
    return DailySummary(
      totalSales: totalSales,
      totalCollected: totalCollected,
      invoiceCount: dayInvoices.length,
      totalPending: totalPending,
    );
  }

  Future<PeriodSummary> getPeriodSummary(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day)
        .millisecondsSinceEpoch;
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final periodInvoices = await (select(invoices)
          ..where((i) =>
              i.invoiceDate.isBiggerOrEqualValue(start) &
              i.invoiceDate.isSmallerOrEqualValue(end)))
        .get();
    final totalSales =
        periodInvoices.fold(0.0, (s, i) => s + i.total);
    final totalCollected =
        periodInvoices.fold(0.0, (s, i) => s + i.paidAmount);
    final totalPending =
        periodInvoices.fold(0.0, (s, i) => s + i.balanceAmount);
    return PeriodSummary(
      totalSales: totalSales,
      totalCollected: totalCollected,
      totalPending: totalPending,
      invoiceCount: periodInvoices.length,
      avgInvoiceValue: periodInvoices.isEmpty
          ? 0
          : totalSales / periodInvoices.length,
    );
  }

  Future<CustomerReport> getCustomerReport(String customerId) async {
    final invList = await getCustomerInvoices(customerId);
    final totalBilled = invList.fold(0.0, (s, i) => s + i.total);
    final totalPaid = invList.fold(0.0, (s, i) => s + i.paidAmount);
    final totalPending = invList.fold(0.0, (s, i) => s + i.balanceAmount);
    return CustomerReport(
      totalBilled: totalBilled,
      totalPaid: totalPaid,
      totalPending: totalPending,
      invoiceCount: invList.length,
      invoices: invList,
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

  // ── BACKUP ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> exportAllData() async {
    return {
      'customers': (await getAllCustomers())
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'address': c.address,
                'creditLimit': c.creditLimit,
                'createdAt': c.createdAt,
              })
          .toList(),
      'items': (await getAllItems())
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'unit': i.unit,
                'defaultRate': i.defaultRate,
                'gstPercent': i.gstPercent,
                'currentStock': i.currentStock,
                'lowStockAlert': i.lowStockAlert,
                'createdAt': i.createdAt,
              })
          .toList(),
      'settings': await getAllSettings(),
    };
  }
}

// ── DB CONNECTION ──────────────────────────────────────────────
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'arthaflow.db'));
    return NativeDatabase(file);
  });
}
