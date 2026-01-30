class Payment {
  final String id;
  final String customerId;
  final int paymentDate;
  final double amount;
  final String mode;
  final String? reference;
  final String? notes;
  final int createdAt;

  Payment({
    required this.id,
    required this.customerId,
    required this.paymentDate,
    required this.amount,
    required this.mode,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  Payment copyWith({
    String? id,
    String? customerId,
    int? paymentDate,
    double? amount,
    String? mode,
    String? reference,
    String? notes,
    int? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
