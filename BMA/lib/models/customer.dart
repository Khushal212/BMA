class Customer {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final double creditLimit;
  final double? defaultPricePercent;
  final double defaultGstPercent;
  final int createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.creditLimit,
    this.defaultPricePercent,
    required this.defaultGstPercent,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? creditLimit,
    double? defaultPricePercent,
    double? defaultGstPercent,
    int? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      defaultPricePercent: defaultPricePercent ?? this.defaultPricePercent,
      defaultGstPercent: defaultGstPercent ?? this.defaultGstPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
