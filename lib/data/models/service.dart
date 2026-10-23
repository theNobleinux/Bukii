class ServiceOffering {
  const ServiceOffering({
    this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    this.description,
    this.maxCapacity = 1,
  });

  /// Supabase `services.id`. Null only for local sample data.
  final String? id;
  final String name;
  final int durationMinutes;
  final int price;
  final String? description;

  /// 1 = one customer at a time, more than 1 = group session.
  final int maxCapacity;

  bool get isGroup => maxCapacity > 1;

  factory ServiceOffering.fromJson(Map<String, dynamic> json) =>
      ServiceOffering(
        id: json['id'] as String?,
        name: json['name'] as String? ?? json['service_name'] as String? ?? '',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.round() ?? 0,
        description: json['description'] as String?,
        maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceOffering &&
      (id != null ? other.id == id : other.name == name && other.price == price);

  @override
  int get hashCode => id?.hashCode ?? Object.hash(name, price);
}
