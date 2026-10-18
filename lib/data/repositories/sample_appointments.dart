import '../models/appointment.dart';
import '../models/provider.dart';
import '../models/service.dart';
import 'sample_providers.dart';

List<Appointment> createSampleAppointments(DateTime today) {
  final fadeLab = sampleProviders.first;
  final haircutAndBeard = fadeLab.services[2];
  final beardTrim = fadeLab.services[1];
  final moraStudio = sampleProviders[1];

  return [
    Appointment(
      provider: fadeLab,
      services: [haircutAndBeard],
      dateTime: DateTime(today.year, today.month, today.day + 2, 10, 30),
      staffName: 'Tunde',
      reference: 'SL-20481',
    ),
    Appointment(
      provider: fadeLab,
      services: [haircutAndBeard],
      dateTime: DateTime(today.year, today.month, today.day - 3, 11),
      staffName: 'Tunde',
      reference: 'SL-19950',
      status: AppointmentStatus.completed,
    ),
    Appointment(
      provider: fadeLab,
      services: [beardTrim],
      dateTime: DateTime(today.year, today.month, today.day - 9, 11),
      staffName: 'Tunde',
      reference: 'SL-19220',
      status: AppointmentStatus.completed,
    ),
    Appointment(
      provider: moraStudio,
      services: [moraStudio.services.first],
      dateTime: DateTime(today.year, today.month, today.day - 22, 14, 30),
      staffName: 'Nneka',
      reference: 'SL-18026',
      status: AppointmentStatus.completed,
    ),
  ];
}

Appointment createAppointment({
  required ServiceProvider provider,
  required List<ServiceOffering> services,
  required DateTime dateTime,
  required String reference,
}) {
  return Appointment(
    provider: provider,
    services: services,
    dateTime: dateTime,
    staffName: 'Tunde',
    reference: reference,
  );
}
