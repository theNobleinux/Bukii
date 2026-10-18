import 'package:flutter/material.dart';

import '../data/models/appointment.dart';
import '../data/repositories/sample_appointments.dart';
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
  late final List<Appointment> _appointments = createSampleAppointments(
    DateTime.now(),
  );
  var _selectedIndex = 0;

  void _addAppointment(Appointment appointment) {
    setState(() => _appointments.insert(0, appointment));
  }

  void _updateAppointment(Appointment updatedAppointment) {
    final index = _appointments.indexWhere(
      (appointment) => appointment.reference == updatedAppointment.reference,
    );
    if (index == -1) return;
    setState(() => _appointments[index] = updatedAppointment);
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
            ExploreTabScreen(
              onShowBookings: _showBookings,
              onBookingConfirmed: _addAppointment,
              onViewBookings: _showBookings,
              onBackToExplore: _showExplore,
            ),
            BookingsScreen(
              appointments: _appointments,
              onUpdateAppointment: _updateAppointment,
            ),
            HistoryScreen(
              appointments: _appointments,
              onBookAgain: _showExplore,
            ),
            ProfileScreen(phoneNumber: widget.phoneNumber),
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
