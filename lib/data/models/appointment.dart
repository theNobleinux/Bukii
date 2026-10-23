import 'provider.dart';
import 'service.dart';

enum AppointmentStatus { upcoming, completed, cancelled }

enum PaymentMethod {
  payOnArrival('pay_on_arrival', 'Pay on arrival'),
  cash('cash', 'Cash'),
  card('card', 'Card');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String? value) => PaymentMethod.values
      .firstWhere((m) => m.apiValue == value, orElse: () => payOnArrival);
}

class Appointment {
  const Appointment({
    this.id,
    required this.provider,
    required this.services,
    required this.dateTime,
    required this.staffName,
    required this.reference,
    this.status = AppointmentStatus.upcoming,
    this.isPending = false,
    this.paymentMethod = PaymentMethod.payOnArrival,
    this.totalPriceOverride,
  });

  /// Supabase `bookings.id`. Null only for local sample data.
  final String? id;
  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final DateTime dateTime;
  final String staffName;
  final String reference;
  final AppointmentStatus status;

  /// Upcoming but still waiting for the business to confirm.
  final bool isPending;
  final PaymentMethod paymentMethod;

  /// Price saved on the booking (prices can change later).
  final int? totalPriceOverride;

  int get totalPrice =>
      totalPriceOverride ??
      services.fold(0, (total, service) => total + service.price);

  int get durationMinutes =>
      services.fold(0, (total, service) => total + service.durationMinutes);

  String get serviceNames =>
      services.map((service) => service.name).join(' + ');

  Appointment copyWith({
    DateTime? dateTime,
    AppointmentStatus? status,
    String? staffName,
  }) => Appointment(
    id: id,
    provider: provider,
    services: services,
    dateTime: dateTime ?? this.dateTime,
    staffName: staffName ?? this.staffName,
    reference: reference,
    status: status ?? this.status,
    isPending: isPending,
    paymentMethod: paymentMethod,
    totalPriceOverride: totalPriceOverride,
  );
}
