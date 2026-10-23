import 'package:flutter/material.dart';

import '../../data/models/appointment.dart';
import '../../data/models/provider.dart';
import '../../theme/app_theme.dart';
import '../service_details_screen.dart';
import '../components/provider_card.dart';

class ExploreTabScreen extends StatefulWidget {
  const ExploreTabScreen({
    super.key,
    required this.providers,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.firstName = 'there',
    required this.onShowBookings,
    required this.onBookingConfirmed,
    required this.onViewBookings,
    required this.onBackToExplore,
  });

  final List<ServiceProvider> providers;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String firstName;
  final VoidCallback onShowBookings;
  final ValueChanged<Appointment> onBookingConfirmed;
  final VoidCallback onViewBookings;
  final VoidCallback onBackToExplore;

  @override
  State<ExploreTabScreen> createState() => _ExploreTabScreenState();
}

class _ExploreTabScreenState extends State<ExploreTabScreen> {
  static const _serviceCategories = [
    'All',
    'Barber',
    'Salon',
    'Nailtech',
    'Spa',
  ];
  static const _popularServices = ['Haircut', 'Braids & twists'];

  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  static const _allAreas = 'All areas, Lagos';
  String _location = _allAreas;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceProvider> get _visibleProviders {
    final query = _query.trim().toLowerCase();
    final selectedLocation = _location.split(',').first.toLowerCase();
    return widget.providers.where((provider) {
      final matchesCategory =
          _selectedCategory == 'All' || provider.category == _selectedCategory;
      final matchesLocation =
          _location == _allAreas ||
          provider.location.toLowerCase() == selectedLocation;
      final matchesQuery =
          query.isEmpty ||
          provider.name.toLowerCase().contains(query) ||
          provider.category.toLowerCase().contains(query) ||
          provider.location.toLowerCase().contains(query) ||
          provider.services.any(
            (service) => service.name.toLowerCase().contains(query),
          );
      return matchesCategory && matchesLocation && matchesQuery;
    }).toList();
  }

  String _todayLabel(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1].toUpperCase()}, '
        '${date.day} ${months[date.month - 1].toUpperCase()}';
  }

  String _greeting(DateTime date) {
    if (date.hour < 12) return 'Good morning,';
    if (date.hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _choosePopularService(String service) {
    setState(() {
      _selectedCategory = 'All';
      _query = service;
      _searchController.value = TextEditingValue(
        text: service,
        selection: TextSelection.collapsed(offset: service.length),
      );
    });
  }

  void _showProvider(ServiceProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceDetailsScreen(
          provider: provider,
          onBookingConfirmed: widget.onBookingConfirmed,
          onViewBookings: widget.onViewBookings,
          onBackToExplore: widget.onBackToExplore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final providers = _visibleProviders;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todayLabel(today),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_greeting(today)}\n${widget.firstName}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Material(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(17),
                  child: IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You’re all caught up.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black,
                      size: 23,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Service, place and business',
                hintStyle: const TextStyle(
                  color: Color(0xFF6F6B66),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF68645F),
                  size: 22,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: AppColors.paper,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),

        // popular locations and services
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          sliver: SliverToBoxAdapter(
            child: PopupMenuButton<String>(
              tooltip: 'Choose location',
              onSelected: (location) => setState(() => _location = location),
              itemBuilder: (context) => const [
                PopupMenuItem(value: _allAreas, child: Text(_allAreas)),
                PopupMenuItem(
                  value: 'Ikoyi, Lagos',
                  child: Text('Ikoyi, Lagos'),
                ),
                PopupMenuItem(
                  value: 'Lekki, Lagos',
                  child: Text('Lekki, Lagos'),
                ),
                PopupMenuItem(
                  value: 'Victoria Island, Lagos',
                  child: Text('Victoria Island, Lagos'),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 19,
                    color: Color(0xFF68645F),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _location,
                    style: const TextStyle(
                      color: Color(0xFF68645F),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Color(0xFF68645F),
                  ),
                ],
              ),
            ),
          ),
        ),

        // categories section
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _serviceCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final category = _serviceCategories[index];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    selectedColor: AppColors.orange,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  );
                },
              ),
            ),
          ),
        ),

        SliverPersistentHeader(
          pinned: true,
          delegate: _NearYouHeaderDelegate(
            onShowBookings: widget.onShowBookings,
          ),
        ),

        // providers list section
        if (widget.isLoading && widget.providers.isEmpty)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            ),
          )
        else if (widget.errorMessage != null && widget.providers.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFF6F6B66),
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6F6B66),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (providers.isEmpty)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 230,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Color(0xFF6F6B66),
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No matches yet',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Try a different service or area.',
                      style: TextStyle(color: Color(0xFF6F6B66), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            sliver: SliverList.separated(
              itemCount: providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => ProviderCard(
                provider: providers[index],
                onTap: () => _showProvider(providers[index]),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Popular services',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Book a little time for yourself',
                  style: TextStyle(color: Color(0xFF6F6B66), fontSize: 14),
                ),
                const SizedBox(height: 12),
                Material(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < _popularServices.length;
                        index++
                      ) ...[
                        if (index > 0)
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: Color(0xFFDAD6D0),
                          ),
                        ListTile(
                          key: ValueKey(
                            'popular-service-${_popularServices[index]}',
                          ),
                          onTap: () =>
                              _choosePopularService(_popularServices[index]),
                          leading: const Icon(
                            Icons.content_cut_rounded,
                            color: AppColors.ink,
                            size: 22,
                          ),
                          title: Text(
                            _popularServices[index],
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF817D77),
                            size: 21,
                          ),
                          dense: true,
                          visualDensity: const VisualDensity(vertical: 1),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 22)),
      ],
    );
  }
}

class _NearYouHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NearYouHeaderDelegate({required this.onShowBookings});

  final VoidCallback onShowBookings;

  @override
  double get minExtent => 92;

  @override
  double get maxExtent => 92;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Near you',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Good people, close by',
                  style: TextStyle(color: Color(0xFF6F6B66), fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onShowBookings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              padding: EdgeInsets.zero,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('See all'),
                SizedBox(width: 3),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_NearYouHeaderDelegate oldDelegate) =>
      oldDelegate.onShowBookings != onShowBookings;
}
