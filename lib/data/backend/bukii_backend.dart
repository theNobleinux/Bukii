import '../models/appointment.dart';
import '../models/provider.dart';
import '../models/service.dart';
import '../models/time_slot.dart';
import '../models/user_profile.dart';
import 'demo_backend.dart';

/// Everything the app needs from the server.
///
/// `main.dart` sets [instance] to the Supabase implementation. Widget tests
/// keep the in-memory [DemoBackend] so they run without a network.
abstract class BukiiBackend {
  static BukiiBackend instance = DemoBackend();

  // ---- auth ----------------------------------------------------------------
  bool get isSignedIn;

  /// Sends a one-time code by SMS. [phone] must be E.164, e.g. +2348012345678.
  Future<void> sendOtp({required String phone, required UserRole role});

  Future<UserProfile> verifyOtp({required String phone, required String code});

  Future<UserProfile?> currentProfile();

  Future<UserProfile> updateProfile({
    String? fullName,
    bool? remindersEnabled,
    bool? whatsappUpdates,
  });

  Future<void> signOut();

  // ---- explore -------------------------------------------------------------
  Future<List<ServiceProvider>> fetchProviders();

  Future<List<ServiceProvider>> savedProviders();

  Future<void> setSaved(ServiceProvider provider, {required bool saved});

  // ---- booking -------------------------------------------------------------
  Future<List<TimeSlot>> availableSlots({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required DateTime date,
  });

  Future<Appointment> createBooking({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required TimeSlot slot,
    PaymentMethod paymentMethod = PaymentMethod.payOnArrival,
    String? notes,
  });

  Future<List<Appointment>> myAppointments();

  Future<Appointment> cancelBooking(Appointment appointment, {String? reason});

  Future<Appointment> rescheduleBooking(Appointment appointment, TimeSlot slot);
}

/// A user-friendly error. [message] is safe to show in a SnackBar.
class BackendException implements Exception {
  const BackendException(this.message, {this.code});

  final String message;

  /// Machine-readable reason from the database, e.g. `slot_unavailable`,
  /// `too_soon`, `outside_hours`, `not_signed_in`.
  final String? code;

  bool get isSlotTaken => code == 'slot_unavailable';
  bool get needsSignIn => code == 'not_signed_in';

  @override
  String toString() => message;
}
