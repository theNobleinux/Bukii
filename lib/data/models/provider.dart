import 'service.dart';

class ServiceProvider {
  const ServiceProvider({
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.distance,
    required this.startingPrice,
    required this.services,
  });

  final String name;
  final String category;
  final String location;
  final double rating;
  final String distance;
  final String startingPrice;
  final List<ServiceOffering> services;
}
