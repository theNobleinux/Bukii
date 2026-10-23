import 'package:flutter/material.dart';

import '../data/backend/bukii_backend.dart';
import '../data/models/appointment.dart';
import '../data/models/provider.dart';
import '../data/models/service.dart';
import '../data/models/time_slot.dart';
import '../theme/app_theme.dart';
import '../utils/booking_formatters.dart';
import 'booking_confirmation_screen.dart';
import 'components/primary_action_button.dart';
import 'components/provider_photo.dart';
import 'components/slot_picker_sheet.dart';
import 'phone_signin_screen.dart';

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
  TimeSlot? _slot;
  var _paymentMethod = PaymentMethod.payOnArrival;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _services = List.of(widget.services);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  /// Chosen time, or the start of the chosen day until a time is picked.
  DateTime get _appointmentDateTime => _slot?.start.toLocal() ?? _date;

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
    if (selectedService != null && selectedService != _services.first) {
      setState(() {
        _services = [selectedService];
        _slot = null;
      });
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
      setState(() {
        _date = selected;
        _slot = null;
      });
      if (!mounted) return;
      await _editTime();
    }
  }

  Future<void> _editTime() async {
    final selected = await showSlotPicker(
      context,
      provider: widget.provider,
      services: _services,
      date: _date,
    );
    if (selected != null && mounted) setState(() => _slot = selected);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmBooking() async {
    final slot = _slot;
    if (slot == null) {
      await _editTime();
      return;
    }
    if (!BukiiBackend.instance.isSignedIn) {
      _showError('Sign in with your phone number to book.');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PhoneSigninScreen(audience: 'Customer'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final appointment = await BukiiBackend.instance.createBooking(
        provider: widget.provider,
        services: _services,
        slot: slot,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      widget.onBookingConfirmed(appointment);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingConfirmationScreen(
            appointment: appointment,
            onViewBookings: widget.onViewBookings,
            onBackToExplore: widget.onBackToExplore,
          ),
        ),
      );
    } on BackendException catch (error) {
      if (!mounted) return;
      if (error.isSlotTaken) setState(() => _slot = null);
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                    timeLabel: _slot?.label,
                    onEditDate: _editDate,
                    onEditService: _editServices,
                    onEditTime: _editTime,
                  ),
                  const SizedBox(height: 16),
                  _PaymentCard(
                    value: _paymentMethod,
                    onChanged: (method) =>
                        setState(() => _paymentMethod = method),
                  ),
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
                    label: _submitting
                        ? 'Booking...'
                        : _slot == null
                        ? 'Choose a time'
                        : 'Confirm booking',
                    onPressed: _submitting ? null : _confirmBooking,
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
    required this.timeLabel,
    required this.onEditDate,
    required this.onEditService,
    required this.onEditTime,
  });

  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final DateTime date;
  final DateTime time;
  final String? timeLabel;
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
                  '${timeLabel ?? 'Tap to choose a time'} · '
                  '${services.fold(0, (total, service) => total + service.durationMinutes)} min',
              onEdit: onEditDate,
            ),
            const SizedBox(height: 15),
            _SummaryRow(
              icon: Icons.content_cut_rounded,
              title: services.map((service) => service.name).join(' + '),
              subtitle: 'With any available professional',
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.value, required this.onChanged});

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

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
              child: DropdownButton<PaymentMethod>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.orange,
                ),
                items: [
                  for (final method in PaymentMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (method) {
                  if (method != null) onChanged(method);
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
                    value == PaymentMethod.payOnArrival
                        ? 'Cash or card at the business'
                        : value.label,
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
