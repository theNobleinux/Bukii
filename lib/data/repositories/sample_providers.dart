import '../models/provider.dart';
import '../models/service.dart';

const sampleProviders = [
  ServiceProvider(
    name: 'Fade Lab',
    category: 'Barber',
    location: 'Ikoyi',
    rating: 4.6,
    distance: '1.2 km away',
    startingPrice: '₦6,000',
    services: [
      ServiceOffering(name: 'Haircut', durationMinutes: 30, price: 12000),
      ServiceOffering(name: 'Beard trim', durationMinutes: 30, price: 6000),
      ServiceOffering(
        name: 'Haircut + Beard',
        durationMinutes: 30,
        price: 18000,
      ),
      ServiceOffering(name: 'Kid’s Cut', durationMinutes: 25, price: 9000),
    ],
  ),
  ServiceProvider(
    name: 'Mora Studio',
    category: 'Salon',
    location: 'Lekki',
    rating: 4.6,
    distance: '2.4 km away',
    startingPrice: '₦8,500',
    services: [
      ServiceOffering(name: 'Haircut', durationMinutes: 30, price: 8500),
      ServiceOffering(
        name: 'Braids & twists',
        durationMinutes: 90,
        price: 25000,
      ),
      ServiceOffering(name: 'Hair styling', durationMinutes: 45, price: 12000),
    ],
  ),
  ServiceProvider(
    name: 'Braid & Bloom',
    category: 'Salon',
    location: 'Ikoyi',
    rating: 4.9,
    distance: '0.8 km away',
    startingPrice: '₦12,000',
    services: [
      ServiceOffering(
        name: 'Braids & twists',
        durationMinutes: 90,
        price: 30000,
      ),
      ServiceOffering(name: 'Hair styling', durationMinutes: 45, price: 15000),
    ],
  ),
];
