/// A bookable start time returned by `get_available_slots`.
class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    required this.label,
    this.availableStaffIds = const [],
    this.spotsLeft = 1,
  });

  /// Exact instant (UTC). Send this back to create / reschedule a booking.
  final DateTime start;
  final DateTime end;

  /// Time in the business timezone, e.g. "10:30 AM".
  final String label;
  final List<String> availableStaffIds;
  final int spotsLeft;

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final local = json['local_time'] as String? ?? '00:00';
    final parts = local.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return TimeSlot(
      start: DateTime.parse(json['slot_start'] as String).toUtc(),
      end: DateTime.parse(json['slot_end'] as String).toUtc(),
      label: '$displayHour:$minute ${hour < 12 ? 'AM' : 'PM'}',
      availableStaffIds:
          (json['available_staff'] as List?)?.cast<String>() ?? const [],
      spotsLeft: (json['spots_left'] as num?)?.toInt() ?? 1,
    );
  }
}
