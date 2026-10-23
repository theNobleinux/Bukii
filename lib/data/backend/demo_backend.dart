import '../models/appointment.dart';
import '../models/provider.dart';
import '../models/service.dart';
import '../models/time_slot.dart';
import '../models/user_profile.dart';
import '../repositories/sample_appointments.dart';
import '../repositories/sample_providers.dart';
import 'bukii_backend.dart';

/// In-memory backend used by widget tests and offline demos.
class DemoBackend implements BukiiBackend {
  /// [signedIn] false starts at the welcome flow (no saved session).
  DemoBackend({bool signedIn = true}) : _profile = signedIn ? _demoUser : null;

  static const _demoUser = UserProfile(
    id: 'demo-user',
    role: UserRole.customer,
    fullName: 'Amara Okafor',
    phone: '+2348012345678',
  );

  UserProfile? _profile;
  late final List<Appointment> _appointments = createSampleAppointments(
    DateTime.now(),
  );
  final Set<ServiceProvider> _saved = {...sampleProviders.take(2)};

  @override
  bool get isSignedIn => _profile != null;

  @override
  Future<void> sendOtp({required String phone, required UserRole role}) async {}

  @override
  Future<UserProfile> verifyOtp({
    required String phone,
    required String code,
  }) async {
    if (code.length != 6) {
      throw const BackendException('Enter the complete 6-digit code.');
    }
    return _profile ??= _demoUser;
  }

  @override
  Future<UserProfile?> currentProfile() async => _profile;

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    bool? remindersEnabled,
    bool? whatsappUpdates,
  }) async {
    final current = _profile;
    if (current == null) {
      throw const BackendException('Please sign in.', code: 'not_signed_in');
    }
    return _profile = current.copyWith(
      fullName: fullName,
      remindersEnabled: remindersEnabled,
      whatsappUpdates: whatsappUpdates,
    );
  }

  @override
  Future<void> signOut() async => _profile = null;

  @override
  Future<List<ServiceProvider>> fetchProviders() async => sampleProviders;

  @override
  Future<List<ServiceProvider>> savedProviders() async => _saved.toList();

  @override
  Future<void> setSaved(ServiceProvider provider, {required bool saved}) async {
    saved ? _saved.add(provider) : _saved.remove(provider);
  }

  @override
  Future<List<TimeSlot>> availableSlots({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final slots = <TimeSlot>[];
    for (var minutes = 9 * 60; minutes <= 17 * 60; minutes += 30) {
      final start = DateTime(
        date.year,
        date.month,
        date.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (start.isBefore(now)) continue;
      final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
      slots.add(
        TimeSlot(
          start: start.toUtc(),
          end: start.add(const Duration(minutes: 30)).toUtc(),
          label:
              '$hour:${start.minute.toString().padLeft(2, '0')} '
              '${start.hour < 12 ? 'AM' : 'PM'}',
        ),
      );
    }
    return slots;
  }

  @override
  Future<Appointment> createBooking({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required TimeSlot slot,
    PaymentMethod paymentMethod = PaymentMethod.payOnArrival,
    String? notes,
  }) async {
    final appointment = createAppointment(
      provider: provider,
      services: services,
      dateTime: slot.start.toLocal(),
      reference:
          'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _appointments.insert(0, appointment);
    return appointment;
  }

  @override
  Future<List<Appointment>> myAppointments() async => List.of(_appointments);

  @override
  Future<Appointment> cancelBooking(
    Appointment appointment, {
    String? reason,
  }) async => _replace(
    appointment,
    appointment.copyWith(status: AppointmentStatus.cancelled),
  );

  @override
  Future<Appointment> rescheduleBooking(
    Appointment appointment,
    TimeSlot slot,
  ) async =>
      _replace(appointment, appointment.copyWith(dateTime: slot.start.toLocal()));

  Appointment _replace(Appointment old, Appointment updated) {
    final index = _appointments.indexWhere((a) => a.reference == old.reference);
    if (index != -1) _appointments[index] = updated;
    return updated;
  }
}
