import 'provider.dart';
import 'service.dart';

enum AppointmentStatus { upcoming, completed, cancelled }

class Appointment {
  const Appointment({
    required this.provider,
    required this.services,
    required this.dateTime,
    required this.staffName,
    required this.reference,
    this.status = AppointmentStatus.upcoming,
  });

  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final DateTime dateTime;
  final String staffName;
  final String reference;
  final AppointmentStatus status;

  int get totalPrice =>
      services.fold(0, (total, service) => total + service.price);

  int get durationMinutes =>
      services.fold(0, (total, service) => total + service.durationMinutes);

  String get serviceNames =>
      services.map((service) => service.name).join(' + ');

  Appointment copyWith({DateTime? dateTime, AppointmentStatus? status}) =>
      Appointment(
        provider: provider,
        services: services,
        dateTime: dateTime ?? this.dateTime,
        staffName: staffName,
        reference: reference,
        status: status ?? this.status,
      );
}
