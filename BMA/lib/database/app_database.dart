@@ -1,83 +1,71 @@
// ADD these methods INSIDE the AppDatabase class
// (paste before the closing } of AppDatabase)
// 1. UPDATE the @DriftDatabase annotation at the top:
@DriftDatabase(
  tables: [
    Customers, Items, Invoices, InvoiceLines,
    Payments, Settings, StockMovements, StaffUsers,
  ],
)

  // ── PARTIAL PAYMENT on specific invoice ───────────────────────
  Future<void> recordPartialPayment({
    required String id,
    required String customerId,
    required String invoiceId,
    required double amount,
    required String mode,
    String? reference,
    String? notes,
  }) async {
    // Record the payment
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
// 2. UPDATE schemaVersion to 3:
@override
int get schemaVersion => 3;

    // Update the invoice balance
    final inv = await getInvoice(invoiceId);
    if (inv != null) {
      final newBalance =
          (inv.balanceAmount - amount).clamp(0.0, double.infinity);
      final newPaid = inv.paidAmount + amount;
      await (update(invoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(InvoicesCompanion(
        paidAmount: Value(newPaid),
        balanceAmount: Value(newBalance),
      ));
// 3. UPDATE migration strategy:
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (migrator, from, to) async {
    if (from < 2) {
      await migrator.addColumn(items, items.currentStock);
      await migrator.addColumn(items, items.lowStockAlert);
      await migrator.createTable(stockMovements);
    }
  }

  // Get invoice-level payments (by reference to invoiceId in notes)
  Future<double> getInvoicePaidAmount(String invoiceId) async {
    final inv = await getInvoice(invoiceId);
    return inv?.paidAmount ?? 0;
  }
    if (from < 3) {
      await migrator.createTable(staffUsers);
      await migrator.addColumn(invoices, invoices.createdBy);
    }
  },
);

  // ── BULK WHATSAPP — get all pending customers ──────────────────
  Future<List<Map<String, dynamic>>> getPendingCustomersForReminder({
    int minDays = 7,
  }) async {
    final allCustomers = await getAllCustomers();
    final result = <Map<String, dynamic>>[];
// 4. ADD these methods INSIDE the AppDatabase class
// (paste before the closing } of AppDatabase):

    for (final c in allCustomers) {
      final outstanding = await getCustomerOutstanding(c.id);
      if (outstanding <= 0) continue;
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

      final invoices = await getCustomerInvoices(c.id);
      final pendingInvoices =
          invoices.where((i) => i.balanceAmount > 0).toList();
      if (pendingInvoices.isEmpty) continue;
  Future<List<StaffUser>> getAllStaff() =>
      select(staffUsers).get();

      final lastInvoice = pendingInvoices.first;
      final daysSince = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(
              lastInvoice.invoiceDate))
          .inDays;
  Future<StaffUser?> getStaffById(String id) =>
      (select(staffUsers)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

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
  Future<void> updateStaff(StaffUser staff) =>
      update(staffUsers).replace(staff);

    result.sort((a, b) => (b['outstanding'] as double)
        .compareTo(a['outstanding'] as double));
    return result;
  }
  Future<void> deleteStaff(String id) =>
      (delete(staffUsers)..where((s) => s.id.equals(id)))
          .go();
