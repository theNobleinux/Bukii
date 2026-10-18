import 'package:flutter/material.dart';

import '../../data/models/appointment.dart';
import '../../theme/app_theme.dart';
import '../components/appointment_card.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    required this.appointments,
    required this.onUpdateAppointment,
  });

  final List<Appointment> appointments;
  final ValueChanged<Appointment> onUpdateAppointment;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  var _showPast = false;

  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: const Text('Cancel this booking?'),
        content: const Text('You can make a new booking any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onUpdateAppointment(
        appointment.copyWith(status: AppointmentStatus.cancelled),
      );
    }
  }

  Future<void> _reschedule(Appointment appointment) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.dateTime.isAfter(today)
          ? appointment.dateTime
          : today.add(const Duration(days: 1)),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (date == null) return;
    widget.onUpdateAppointment(
      appointment.copyWith(
        dateTime: DateTime(
          date.year,
          date.month,
          date.day,
          appointment.dateTime.hour,
          appointment.dateTime.minute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = widget.appointments
        .where(
          (appointment) => appointment.status == AppointmentStatus.upcoming,
        )
        .toList();
    final past = widget.appointments
        .where(
          (appointment) => appointment.status != AppointmentStatus.upcoming,
        )
        .toList();
    final appointments = _showPast ? past : upcoming;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR TIME, AT A GLANCE',
                  style: TextStyle(
                    color: Color(0xFF9A938D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bookings',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      _BookingFilter(
                        label: 'Upcoming',
                        selected: !_showPast,
                        onTap: () => setState(() => _showPast = false),
                      ),
                      _BookingFilter(
                        label: 'Past',
                        selected: _showPast,
                        onTap: () => setState(() => _showPast = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _showPast ? 'PAST VISITS' : 'UP NEXT',
                  style: const TextStyle(
                    color: Color(0xFF9A938D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        if (appointments.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.orange,
                      size: 38,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _showPast
                          ? 'Your past visits will show here.'
                          : 'No upcoming bookings yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            sliver: SliverList.separated(
              itemCount: appointments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final appointment = appointments[index];
                return AppointmentCard(
                  appointment: appointment,
                  showActions:
                      !_showPast &&
                      appointment.status == AppointmentStatus.upcoming,
                  onReschedule: () => _reschedule(appointment),
                  onCancel: () => _cancel(appointment),
                );
              },
            ),
          ),
        if (!_showPast && appointments.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            sliver: const SliverToBoxAdapter(child: _ReminderCard()),
          ),
      ],
    );
  }
}

class _BookingFilter extends StatelessWidget {
  const _BookingFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Icon(Icons.notifications_none_rounded, color: AppColors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Never miss a visit',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Appointment reminders are on',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
