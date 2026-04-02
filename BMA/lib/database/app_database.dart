// ADD these methods INSIDE the AppDatabase class
// (paste before the closing } of AppDatabase)

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
    }
  }

  // Get invoice-level payments (by reference to invoiceId in notes)
  Future<double> getInvoicePaidAmount(String invoiceId) async {
    final inv = await getInvoice(invoiceId);
    return inv?.paidAmount ?? 0;
  }

  // ── BULK WHATSAPP — get all pending customers ──────────────────
  Future<List<Map<String, dynamic>>> getPendingCustomersForReminder({
    int minDays = 7,
  }) async {
    final allCustomers = await getAllCustomers();
    final result = <Map<String, dynamic>>[];

    for (final c in allCustomers) {
      final outstanding = await getCustomerOutstanding(c.id);
      if (outstanding <= 0) continue;

      final invoices = await getCustomerInvoices(c.id);
      final pendingInvoices =
          invoices.where((i) => i.balanceAmount > 0).toList();
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

    result.sort((a, b) => (b['outstanding'] as double)
        .compareTo(a['outstanding'] as double));
    return result;
  }
