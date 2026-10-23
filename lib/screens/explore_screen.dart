import 'package:flutter/material.dart';

import '../data/backend/bukii_backend.dart';
import '../data/models/appointment.dart';
import '../data/models/provider.dart';
import '../data/models/time_slot.dart';
import '../data/models/user_profile.dart';
import '../theme/app_theme.dart';
import 'tabs/bookings_screen.dart';
import 'tabs/explore_tab_screen.dart';
import 'tabs/history_screen.dart';
import 'tabs/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.phoneNumber = '+234 801 234 5678'});

  final String phoneNumber;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _backend = BukiiBackend.instance;

  List<Appointment> _appointments = [];
  List<ServiceProvider> _providers = [];
  UserProfile? _profile;
  var _loadingProviders = true;
  String? _providersError;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadProviders(), _loadAppointments()]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _backend.currentProfile();
      if (mounted) setState(() => _profile = profile);
    } on BackendException {
      // Profile is optional for browsing.
    }
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providersError = null;
    });
    try {
      final providers = await _backend.fetchProviders();
      if (mounted) setState(() => _providers = providers);
    } on BackendException catch (error) {
      if (mounted) setState(() => _providersError = error.message);
    } finally {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final appointments = await _backend.myAppointments();
      if (mounted) setState(() => _appointments = appointments);
    } on BackendException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _addAppointment(Appointment appointment) {
    setState(() => _appointments.insert(0, appointment));
  }

  void _replaceAppointment(Appointment updated) {
    final index = _appointments.indexWhere(
      (appointment) =>
          (updated.id != null && appointment.id == updated.id) ||
          appointment.reference == updated.reference,
    );
    if (index == -1) return;
    setState(() => _appointments[index] = updated);
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    try {
      final updated = await _backend.cancelBooking(appointment);
      _replaceAppointment(updated);
      _showMessage('Booking cancelled.');
    } on BackendException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _rescheduleAppointment(
    Appointment appointment,
    TimeSlot slot,
  ) async {
    try {
      final updated = await _backend.rescheduleBooking(appointment, slot);
      _replaceAppointment(updated);
      _showMessage('Booking moved to ${slot.label}.');
    } on BackendException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showBookings() => setState(() => _selectedIndex = 1);

  void _showExplore() => setState(() => _selectedIndex = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            RefreshIndicator(
              color: AppColors.orange,
              onRefresh: _loadProviders,
              child: ExploreTabScreen(
                providers: _providers,
                isLoading: _loadingProviders,
                errorMessage: _providersError,
                onRetry: _loadProviders,
                firstName: _profile?.firstName ?? 'there',
                onShowBookings: _showBookings,
                onBookingConfirmed: _addAppointment,
                onViewBookings: _showBookings,
                onBackToExplore: _showExplore,
              ),
            ),
            RefreshIndicator(
              color: AppColors.orange,
              onRefresh: _loadAppointments,
              child: BookingsScreen(
                appointments: _appointments,
                onCancel: _cancelAppointment,
                onReschedule: _rescheduleAppointment,
              ),
            ),
            HistoryScreen(
              appointments: _appointments,
              onBookAgain: _showExplore,
            ),
            ProfileScreen(
              phoneNumber: _profile?.phone ?? widget.phoneNumber,
              profile: _profile,
              onProfileChanged: (profile) =>
                  setState(() => _profile = profile),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? AppColors.orange : const Color(0xFF686868),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? AppColors.orange : const Color(0xFF686868),
              size: 25,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: AppColors.canvas,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_outlined),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_outlined),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
