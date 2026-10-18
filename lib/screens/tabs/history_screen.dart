import 'package:flutter/material.dart';

import '../../data/models/appointment.dart';
import '../../theme/app_theme.dart';
import '../../utils/booking_formatters.dart';
import '../components/appointment_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.appointments,
    required this.onBookAgain,
  });

  final List<Appointment> appointments;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final visits =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.completed,
            )
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final spent = visits.fold(0, (total, visit) => total + visit.totalPrice);
    final favorite = visits.isEmpty ? '—' : visits.first.provider.name;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR LOCAL FAVOURITES',
                  style: TextStyle(
                    color: Color(0xFF9A938D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Visit history',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HistoryStat(
                          label: 'VISITS',
                          value: '${visits.length}',
                        ),
                      ),
                      Expanded(
                        child: _HistoryStat(
                          label: 'SPENT',
                          value: formatNaira(spent),
                        ),
                      ),
                      Expanded(
                        child: _HistoryStat(
                          label: 'FAVOURITE',
                          value: favorite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  visits.isEmpty
                      ? 'YOUR VISITS'
                      : formatAppointmentMonth(visits.first.dateTime),
                  style: const TextStyle(
                    color: Color(0xFF9A938D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 13),
              ],
            ),
          ),
        ),
        if (visits.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 32),
              child: Text(
                'Your completed appointments will appear here.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverToBoxAdapter(
              child: AppointmentCard(appointment: visits.first),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            sliver: SliverList.separated(
              itemCount: visits.length - 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFEDE8E2)),
              itemBuilder: (context, index) =>
                  _CompactVisit(appointment: visits[index + 1]),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
          sliver: SliverToBoxAdapter(
            child: OutlinedButton(
              onPressed: onBookAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: Color(0xFFE5DED7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Book a favourite again'),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF9A938D),
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CompactVisit extends StatelessWidget {
  const _CompactVisit({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appointment.dateTime.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatAppointmentMonth(appointment.dateTime).split(' ').first,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.provider.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${appointment.serviceNames} · '
                  '${formatAppointmentTime(appointment.dateTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatNaira(appointment.totalPrice),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
