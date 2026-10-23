import 'package:flutter/material.dart';

import '../../data/backend/bukii_backend.dart';
import '../../data/models/provider.dart';
import '../../data/models/service.dart';
import '../../data/models/time_slot.dart';
import '../../theme/app_theme.dart';
import '../../utils/booking_formatters.dart';

/// Bottom sheet listing real free times for [date] from the backend.
/// Returns the chosen [TimeSlot], or null if dismissed.
Future<TimeSlot?> showSlotPicker(
  BuildContext context, {
  required ServiceProvider provider,
  required List<ServiceOffering> services,
  required DateTime date,
}) {
  return showModalBottomSheet<TimeSlot>(
    context: context,
    backgroundColor: AppColors.canvas,
    isScrollControlled: true,
    builder: (context) =>
        _SlotPicker(provider: provider, services: services, date: date),
  );
}

class _SlotPicker extends StatefulWidget {
  const _SlotPicker({
    required this.provider,
    required this.services,
    required this.date,
  });

  final ServiceProvider provider;
  final List<ServiceOffering> services;
  final DateTime date;

  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  late Future<List<TimeSlot>> _slots = _load();

  Future<List<TimeSlot>> _load() => BukiiBackend.instance.availableSlots(
    provider: widget.provider,
    services: widget.services,
    date: widget.date,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
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
              const SizedBox(height: 4),
              Text(
                formatAppointmentDate(widget.date),
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: FutureBuilder<List<TimeSlot>>(
                  future: _slots,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.orange,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _Message(
                        text: snapshot.error.toString(),
                        actionLabel: 'Try again',
                        onAction: () => setState(() => _slots = _load()),
                      );
                    }
                    final slots = snapshot.data ?? const <TimeSlot>[];
                    if (slots.isEmpty) {
                      return const _Message(
                        text: 'No free times on this day. Try another date.',
                      );
                    }
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final slot in slots)
                            OutlinedButton(
                              key: ValueKey('slot-${slot.label}'),
                              onPressed: () => Navigator.pop(context, slot),
                              child: Text(
                                widget.services.any((s) => s.isGroup)
                                    ? '${slot.label} · ${slot.spotsLeft} left'
                                    : slot.label,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: AppColors.muted)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
