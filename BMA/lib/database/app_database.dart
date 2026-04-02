// 1. UPDATE the @DriftDatabase annotation at the top:
@DriftDatabase(
  tables: [
    Customers, Items, Invoices, InvoiceLines,
    Payments, Settings, StockMovements, StaffUsers,
  ],
)

// 2. UPDATE schemaVersion to 3:
@override
int get schemaVersion => 3;

// 3. UPDATE migration strategy:
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

// 4. ADD these methods INSIDE the AppDatabase class
// (paste before the closing } of AppDatabase):

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
        createdAt:
            Value(DateTime.now().millisecondsSinceEpoch),
      ));

  Future<List<StaffUser>> getAllStaff() =>
      select(staffUsers).get();

  Future<StaffUser?> getStaffById(String id) =>
      (select(staffUsers)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  Future<void> updateStaff(StaffUser staff) =>
      update(staffUsers).replace(staff);

  Future<void> deleteStaff(String id) =>
      (delete(staffUsers)..where((s) => s.id.equals(id)))
          .go();
