import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/backend/bukii_backend.dart';
import '../data/models/appointment.dart';
import '../data/models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/booking_formatters.dart';
import 'components/primary_action_button.dart';
import 'components/provider_photo.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.appointment,
    required this.onViewBookings,
    required this.onBackToExplore,
  });

  final Appointment appointment;
  final VoidCallback onViewBookings;
  final VoidCallback onBackToExplore;

  void _returnToApp(BuildContext context, VoidCallback onReturn) {
    onReturn();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 44,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'YOU’RE ALL SET',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<UserProfile?>(
                        future: BukiiBackend.instance.currentProfile(),
                        builder: (context, snapshot) {
                          final name = snapshot.data?.fullName?.trim() ?? '';
                          return Text(
                            name.isEmpty
                                ? 'It’s booked!'
                                : 'It’s booked,\n${snapshot.data!.firstName}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 36,
                              height: 1.1,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your time at ${appointment.provider.name} is confirmed.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _ConfirmationCard(appointment: appointment),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.orange,
                            size: 21,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'We’ll send you a reminder before your appointment.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              PrimaryActionButton(
                label: 'View my bookings',
                onPressed: () => _returnToApp(context, onViewBookings),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _returnToApp(context, onBackToExplore),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Back to explore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ProviderPhoto(
                    provider: appointment.provider,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.provider.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.serviceNames,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.orange,
                  size: 21,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAppointmentDate(appointment.dateTime),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatAppointmentTime(appointment.dateTime),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'BOOKING REFERENCE',
                  style: TextStyle(
                    color: Color(0xFF9A938D),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    appointment.reference,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: appointment.reference),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking reference copied.'),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.all(4),
                  ),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
