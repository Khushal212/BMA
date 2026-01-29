class Item {
  final String id;
  final String name;
  final String unit;
  final double? defaultRate;
  final double gstPercent;
  final int createdAt;

  Item({
    required this.id,
    required this.name,
    required this.unit,
    this.defaultRate,
    required this.gstPercent,
    required this.createdAt,
  });

  Item copyWith({
    String? id,
    String? name,
    String? unit,
    double? defaultRate,
    double? gstPercent,
    int? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      defaultRate: defaultRate ?? this.defaultRate,
      gstPercent: gstPercent ?? this.gstPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
