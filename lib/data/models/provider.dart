import 'service.dart';

class ServiceProvider {
  const ServiceProvider({
    this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.distance,
    required this.startingPrice,
    required this.services,
    this.ratingCount = 0,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.address,
    this.websiteSlug,
  });

  /// Supabase `businesses.id`. Null only for local sample data.
  final String? id;
  final String name;
  final String category;
  final String location;
  final double rating;
  final int ratingCount;

  /// Short line shown under the provider (distance, or review count until
  /// location-based search is added).
  final String distance;
  final String startingPrice;
  final List<ServiceOffering> services;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? address;
  final String? websiteSlug;

  ServiceProvider copyWith({List<ServiceOffering>? services}) =>
      ServiceProvider(
        id: id,
        name: name,
        category: category,
        location: location,
        rating: rating,
        distance: distance,
        startingPrice: startingPrice,
        services: services ?? this.services,
        ratingCount: ratingCount,
        description: description,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        address: address,
        websiteSlug: websiteSlug,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceProvider &&
      (id != null ? other.id == id : other.name == name);

  @override
  int get hashCode => id?.hashCode ?? name.hashCode;
}
