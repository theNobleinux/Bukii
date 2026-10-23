import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/booking_formatters.dart';
import '../models/appointment.dart';
import '../models/provider.dart';
import '../models/service.dart';
import '../models/time_slot.dart';
import '../models/user_profile.dart';
import 'bukii_backend.dart';

/// Real backend: Supabase Auth (phone OTP), tables, views and RPCs defined
/// in `supabase/migrations`.
class SupabaseBackend implements BukiiBackend {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  static const _bookingColumns = '''
    id, reference, appointment_time, status, staff_name, total_price, payment_method,
    booking_services(service_id, service_name, duration_minutes, price, position),
    businesses(id, name, area, city, address, logo_url, rating_avg, rating_count, categories(name))
  ''';

  String? get _uid => _client.auth.currentUser?.id;

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw const BackendException(
        'Please sign in to continue.',
        code: 'not_signed_in',
      );
    }
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------
  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Future<void> sendOtp({required String phone, required UserRole role}) =>
      _guard(
        () => _client.auth.signInWithOtp(
          phone: phone,
          // Only used the first time this phone signs up (sets profiles.role).
          data: {'role': role.apiValue},
        ),
      );

  @override
  Future<UserProfile> verifyOtp({
    required String phone,
    required String code,
  }) => _guard(() async {
    await _client.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
    final profile = await currentProfile();
    if (profile == null) {
      throw const BackendException('Could not load your account. Try again.');
    }
    return profile;
  });

  @override
  Future<UserProfile?> currentProfile() => _guard(() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : UserProfile.fromJson(row);
  });

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    bool? remindersEnabled,
    bool? whatsappUpdates,
  }) => _guard(() async {
    final uid = _requireUid();
    final row = await _client
        .from('profiles')
        .update({
          'full_name': ?fullName,
          'reminders_enabled': ?remindersEnabled,
          'whatsapp_updates': ?whatsappUpdates,
        })
        .eq('id', uid)
        .select()
        .single();
    return UserProfile.fromJson(row);
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  // ---------------------------------------------------------------------------
  // Explore
  // ---------------------------------------------------------------------------
  @override
  Future<List<ServiceProvider>> fetchProviders() => _guard(() async {
    final listings = await _client
        .from('business_listings')
        .select()
        .order('rating_avg', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return _withServices(listings);
  });

  @override
  Future<List<ServiceProvider>> savedProviders() => _guard(() async {
    final uid = _uid;
    if (uid == null) return const <ServiceProvider>[];
    final saved = await _client
        .from('saved_businesses')
        .select('business_id')
        .eq('customer_id', uid);
    final ids = [for (final row in saved) row['business_id'] as String];
    if (ids.isEmpty) return const <ServiceProvider>[];
    final listings = await _client
        .from('business_listings')
        .select()
        .inFilter('id', ids);
    return _withServices(listings);
  });

  @override
  Future<void> setSaved(ServiceProvider provider, {required bool saved}) =>
      _guard(() async {
        final uid = _requireUid();
        final businessId = _requireId(provider.id);
        if (saved) {
          await _client.from('saved_businesses').upsert({
            'customer_id': uid,
            'business_id': businessId,
          }, ignoreDuplicates: true);
        } else {
          await _client.from('saved_businesses').delete().match({
            'customer_id': uid,
            'business_id': businessId,
          });
        }
      });

  Future<List<ServiceProvider>> _withServices(
    List<Map<String, dynamic>> listings,
  ) async {
    if (listings.isEmpty) return const <ServiceProvider>[];
    final ids = [for (final row in listings) row['id'] as String];
    final serviceRows = await _client
        .from('services')
        .select(
          'id, business_id, name, description, duration_minutes, price, max_capacity, sort_order',
        )
        .eq('is_active', true)
        .inFilter('business_id', ids)
        .order('sort_order')
        .order('price');

    final byBusiness = <String, List<ServiceOffering>>{};
    for (final row in serviceRows) {
      byBusiness
          .putIfAbsent(row['business_id'] as String, () => [])
          .add(ServiceOffering.fromJson(row));
    }
    return [
      for (final row in listings)
        _providerFromJson(row, byBusiness[row['id']] ?? const []),
    ];
  }

  ServiceProvider _providerFromJson(
    Map<String, dynamic> row,
    List<ServiceOffering> services,
  ) {
    final ratingCount = (row['rating_count'] as num?)?.toInt() ?? 0;
    final startingPrice = (row['starting_price'] as num?)?.round();
    return ServiceProvider(
      id: row['id'] as String,
      name: row['name'] as String,
      category:
          row['category_name'] as String? ??
          (row['categories'] as Map?)?['name'] as String? ??
          'Business',
      location: row['area'] as String? ?? row['city'] as String? ?? 'Lagos',
      rating: (row['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: ratingCount,
      distance: ratingCount == 0
          ? 'New on Bukii'
          : '$ratingCount review${ratingCount == 1 ? '' : 's'}',
      startingPrice: startingPrice == null ? '—' : formatNaira(startingPrice),
      services: services,
      description: row['description'] as String?,
      logoUrl: row['logo_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      address: row['address'] as String?,
      websiteSlug: row['website_slug'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Booking
  // ---------------------------------------------------------------------------
  @override
  Future<List<TimeSlot>> availableSlots({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required DateTime date,
  }) => _guard(() async {
    final rows = await _client.rpc(
      'get_available_slots',
      params: {
        'p_business_id': _requireId(provider.id),
        'p_date': _isoDate(date),
        'p_service_ids': [for (final s in services) _requireId(s.id)],
      },
    );
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        TimeSlot.fromJson(row),
    ];
  });

  @override
  Future<Appointment> createBooking({
    required ServiceProvider provider,
    required List<ServiceOffering> services,
    required TimeSlot slot,
    PaymentMethod paymentMethod = PaymentMethod.payOnArrival,
    String? notes,
  }) => _guard(() async {
    _requireUid();
    final json = await _client.rpc(
      'create_booking',
      params: {
        'p_business_id': _requireId(provider.id),
        'p_service_ids': [for (final s in services) _requireId(s.id)],
        'p_start': slot.start.toUtc().toIso8601String(),
        'p_payment_method': paymentMethod.apiValue,
        'p_notes': notes,
      },
    );
    return _appointmentFromRpc(json as Map<String, dynamic>, provider);
  });

  @override
  Future<List<Appointment>> myAppointments() => _guard(() async {
    final uid = _uid;
    if (uid == null) return const <Appointment>[];
    final rows = await _client
        .from('bookings')
        .select(_bookingColumns)
        .eq('customer_id', uid)
        .order('appointment_time', ascending: false)
        .limit(200);
    return [for (final row in rows) _appointmentFromRow(row)];
  });

  @override
  Future<Appointment> cancelBooking(
    Appointment appointment, {
    String? reason,
  }) => _guard(() async {
    final json = await _client.rpc(
      'cancel_booking',
      params: {'p_booking_id': _requireId(appointment.id), 'p_reason': reason},
    );
    return _appointmentFromRpc(
      json as Map<String, dynamic>,
      appointment.provider,
    );
  });

  @override
  Future<Appointment> rescheduleBooking(
    Appointment appointment,
    TimeSlot slot,
  ) => _guard(() async {
    final json = await _client.rpc(
      'reschedule_booking',
      params: {
        'p_booking_id': _requireId(appointment.id),
        'p_new_start': slot.start.toUtc().toIso8601String(),
      },
    );
    return _appointmentFromRpc(
      json as Map<String, dynamic>,
      appointment.provider,
    );
  });

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------
  Appointment _appointmentFromRow(Map<String, dynamic> row) {
    final business = (row['businesses'] as Map?)?.cast<String, dynamic>() ?? {};
    final provider = _providerFromJson({
      ...business,
      'category_name': (business['categories'] as Map?)?['name'],
    }, const []);
    return _appointmentFromRpc(row, provider);
  }

  /// Works for both RPC results (`services` key) and table rows
  /// (`booking_services` key).
  Appointment _appointmentFromRpc(
    Map<String, dynamic> json,
    ServiceProvider provider,
  ) {
    final rawServices =
        (json['services'] ?? json['booking_services']) as List? ?? const [];
    final services =
        rawServices.cast<Map<String, dynamic>>().toList()..sort(
          (a, b) => ((a['position'] as num?) ?? 0).compareTo(
            (b['position'] as num?) ?? 0,
          ),
        );
    final status = json['status'] as String? ?? 'confirmed';
    return Appointment(
      id: json['id'] as String?,
      provider: provider,
      services: [
        for (final s in services)
          ServiceOffering(
            id: s['service_id'] as String?,
            name: s['service_name'] as String? ?? '',
            durationMinutes: (s['duration_minutes'] as num?)?.toInt() ?? 0,
            price: (s['price'] as num?)?.round() ?? 0,
          ),
      ],
      dateTime: DateTime.parse(json['appointment_time'] as String).toLocal(),
      staffName: json['staff_name'] as String? ?? 'Any available',
      reference: json['reference'] as String? ?? '',
      status: switch (status) {
        'completed' => AppointmentStatus.completed,
        'cancelled' || 'no_show' => AppointmentStatus.cancelled,
        _ => AppointmentStatus.upcoming,
      },
      isPending: status == 'pending',
      paymentMethod: PaymentMethod.fromApi(json['payment_method'] as String?),
      totalPriceOverride: (json['total_price'] as num?)?.round(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _requireId(String? id) {
    if (id == null) {
      throw const BackendException(
        'This item is not available online yet.',
        code: 'missing_id',
      );
    }
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on BackendException {
      rethrow;
    } on PostgrestException catch (e) {
      throw BackendException(_friendlyDbMessage(e), code: e.hint ?? e.code);
    } on AuthException catch (e) {
      throw BackendException(_friendlyAuthMessage(e), code: 'auth');
    } catch (e) {
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('Failed host lookup')) {
        throw const BackendException(
          'No internet connection. Check your network and try again.',
          code: 'offline',
        );
      }
      throw const BackendException('Something went wrong. Please try again.');
    }
  }

  static String _friendlyDbMessage(PostgrestException e) {
    // Our database functions raise P0001 with a message written for users.
    if (e.code == 'P0001') return e.message;
    if (e.code == '42501') return 'You are not allowed to do that.';
    if (e.code == '23505') return 'That already exists.';
    return 'Something went wrong. Please try again.';
  }

  static String _friendlyAuthMessage(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('expired') || message.contains('invalid')) {
      return 'That code is wrong or has expired. Request a new one.';
    }
    if (message.contains('rate') || e.statusCode == '429') {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (message.contains('sms') || message.contains('provider')) {
      return 'We could not send an SMS right now. Please try again later.';
    }
    return e.message;
  }
}
