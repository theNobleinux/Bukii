import 'package:flutter/material.dart';

import '../data/models/appointment.dart';
import '../data/models/provider.dart';
import '../data/models/service.dart';
import '../theme/app_theme.dart';
import '../utils/booking_formatters.dart';
import 'booking_details_screen.dart';
import 'components/primary_action_button.dart';
import 'components/provider_photo.dart';

class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.provider,
    required this.onBookingConfirmed,
    required this.onViewBookings,
    required this.onBackToExplore,
  });

  final ServiceProvider provider;
  final ValueChanged<Appointment> onBookingConfirmed;
  final VoidCallback onViewBookings;
  final VoidCallback onBackToExplore;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  ServiceOffering? _selectedService;

  void _continueToBooking() {
    final selectedService = _selectedService;
    if (selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one service to continue.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailsScreen(
          provider: widget.provider,
          services: [selectedService],
          onBookingConfirmed: widget.onBookingConfirmed,
          onViewBookings: widget.onViewBookings,
          onBackToExplore: widget.onBackToExplore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 226,
                      width: double.infinity,
                      child: ProviderPhoto(provider: widget.provider),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.provider.name,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 34,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.orange,
                                size: 27,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'online',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.provider.category} studio · '
                            '${widget.provider.location}, Lagos',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.provider.location}, Lagos',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.muted,
                                size: 19,
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(height: 1),
                          ),
                          const Text(
                            'Choose a service',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'All services include a consultation',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < widget.provider.services.length;
                                  index++
                                ) ...[
                                  if (index > 0)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 0,
                                      ),
                                      child: Divider(height: 1),
                                    ),
                                  _ServiceRow(
                                    key: ValueKey(
                                      'service-${widget.provider.services[index].name}',
                                    ),
                                    service: widget.provider.services[index],
                                    selected: identical(
                                      _selectedService,
                                      widget.provider.services[index],
                                    ),
                                    onTap: () => setState(
                                      () => _selectedService =
                                          widget.provider.services[index],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Opening Hours',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Today',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                '9:00 AM – 8:00 PM',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 16),
              child: PrimaryActionButton(
                label: 'Book Now',
                onPressed: _continueToBooking,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceOffering service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.orange : const Color(0xFF898989),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatDuration(service.durationMinutes),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatNaira(service.price),
              style: const TextStyle(color: AppColors.ink, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
