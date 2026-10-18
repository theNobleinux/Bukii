import 'package:flutter/material.dart';

import '../data/models/appointment.dart';
import '../data/models/provider.dart';
import '../data/models/service.dart';
import '../data/repositories/sample_appointments.dart';
import '../theme/app_theme.dart';
import '../utils/booking_formatters.dart';
import 'booking_confirmation_screen.dart';
import 'components/primary_action_button.dart';
import 'components/provider_photo.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.provider,
    required this.services,
    required this.onBookingConfirmed,
    required this.onViewBookings,
    required this.onBackToExplore,
  });

  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final ValueChanged<Appointment> onBookingConfirmed;
  final VoidCallback onViewBookings;
  final VoidCallback onBackToExplore;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  late List<ServiceOffering> _services;
  late DateTime _date;
  var _hour = 10;
  var _minute = 30;

  @override
  void initState() {
    super.initState();
    _services = List.of(widget.services);
    final tomorrow = DateTime.now().add(const Duration(days: 2));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  DateTime get _appointmentDateTime =>
      DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  int get _total => _services.fold(0, (sum, service) => sum + service.price);

  Future<void> _editServices() async {
    final selectedService = await showModalBottomSheet<ServiceOffering>(
      context: context,
      backgroundColor: AppColors.canvas,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose a service',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            RadioGroup<ServiceOffering>(
              groupValue: _services.first,
              onChanged: (value) {
                if (value != null) Navigator.pop(context, value);
              },
              child: Column(
                children: [
                  for (final service in widget.provider.services)
                    RadioListTile<ServiceOffering>(
                      value: service,
                      title: Text(service.name),
                      subtitle: Text(
                        '${formatDuration(service.durationMinutes)} · '
                        '${formatNaira(service.price)}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedService != null) {
      setState(() => _services = [selectedService]);
    }
  }

  Future<void> _editDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: AppColors.orange, surface: AppColors.canvas),
        ),
        child: child!,
      ),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  Future<void> _editTime() async {
    const slots = ['9:00 AM', '10:30 AM', '12:00 PM', '2:30 PM', '4:00 PM'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.canvas,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a time',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final slot in slots)
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, slot),
                      child: Text(slot),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    final parsed = _parseTime(selected);
    setState(() {
      _hour = parsed.$1;
      _minute = parsed.$2;
    });
  }

  (int, int) _parseTime(String value) {
    final parts = value.split(' ');
    final time = parts.first.split(':');
    var hour = int.parse(time.first);
    final minute = int.parse(time.last);
    if (parts.last == 'PM' && hour != 12) hour += 12;
    if (parts.last == 'AM' && hour == 12) hour = 0;
    return (hour, minute);
  }

  void _confirmBooking() {
    final reference =
        'SL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final appointment = createAppointment(
      provider: widget.provider,
      services: _services,
      dateTime: _appointmentDateTime,
      reference: reference,
    );
    widget.onBookingConfirmed(appointment);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingConfirmationScreen(
          appointment: appointment,
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
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Booking details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                children: [
                  const Text(
                    'Almost there.',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the details before you book.',
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                  const SizedBox(height: 22),
                  _BookingSummaryCard(
                    provider: widget.provider,
                    services: _services,
                    date: _date,
                    time: _appointmentDateTime,
                    onEditDate: _editDate,
                    onEditService: _editServices,
                    onEditTime: _editTime,
                  ),
                  const SizedBox(height: 16),
                  const _PaymentCard(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total due at appointment',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        formatNaira(_total),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
              child: Column(
                children: [
                  PrimaryActionButton(
                    label: 'Confirm booking',
                    onPressed: _confirmBooking,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No payment is taken now. Free cancellation up to 2 hours before.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFAAA49E), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.provider,
    required this.services,
    required this.date,
    required this.time,
    required this.onEditDate,
    required this.onEditService,
    required this.onEditTime,
  });

  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final DateTime date;
  final DateTime time;
  final VoidCallback onEditDate;
  final VoidCallback onEditService;
  final VoidCallback onEditTime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: ProviderPhoto(provider: provider, compact: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${provider.category} studio · ${provider.location}',
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
            _SummaryRow(
              icon: Icons.calendar_month_outlined,
              title: formatAppointmentDate(date),
              subtitle:
                  '${formatAppointmentTime(time)} · '
                  '${services.fold(0, (total, service) => total + service.durationMinutes)} min',
              onEdit: onEditDate,
            ),
            const SizedBox(height: 15),
            _SummaryRow(
              icon: Icons.content_cut_rounded,
              title: services.map((service) => service.name).join(' + '),
              subtitle: 'With Tunde',
              onEdit: onEditService,
              onEditTime: onEditTime,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    this.onEditTime,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback? onEditTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.orange, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onEditTime,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.orange,
            minimumSize: Size.zero,
            padding: const EdgeInsets.all(8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatefulWidget {
  const _PaymentCard();

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  var _paymentMethod = 'Pay on arrival';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paymentMethod,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.orange,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Pay on arrival',
                    child: Text('Pay on arrival'),
                  ),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pay at the business',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.credit_card_outlined,
                  color: AppColors.orange,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _paymentMethod == 'Pay on arrival'
                        ? 'Cash or card at the business'
                        : _paymentMethod,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13),
                  ),
                ),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
