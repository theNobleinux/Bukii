import 'package:flutter/material.dart';

import '../../data/backend/bukii_backend.dart';
import '../../data/models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../audience_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.phoneNumber,
    this.profile,
    this.onProfileChanged,
  });

  final String phoneNumber;
  final UserProfile? profile;
  final ValueChanged<UserProfile>? onProfileChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _backend = BukiiBackend.instance;
  var _name = 'Your name';
  var _remindersEnabled = true;
  var _whatsAppEnabled = false;

  @override
  void initState() {
    super.initState();
    _applyProfile(widget.profile);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile) _applyProfile(widget.profile);
  }

  void _applyProfile(UserProfile? profile) {
    if (profile == null) return;
    final name = profile.fullName?.trim() ?? '';
    _name = name.isEmpty ? 'Add your name' : name;
    _remindersEnabled = profile.remindersEnabled;
    _whatsAppEnabled = profile.whatsappUpdates;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save({
    String? fullName,
    bool? remindersEnabled,
    bool? whatsappUpdates,
  }) async {
    if (!_backend.isSignedIn) return;
    try {
      final profile = await _backend.updateProfile(
        fullName: fullName,
        remindersEnabled: remindersEnabled,
        whatsappUpdates: whatsappUpdates,
      );
      widget.onProfileChanged?.call(profile);
    } on BackendException catch (error) {
      _showMessage(error.message);
      if (mounted) setState(() => _applyProfile(widget.profile));
    }
  }

  Future<void> _editProfile() async {
    final controller = TextEditingController(
      text: widget.profile?.fullName ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: const Text('Edit your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      setState(() => _name = name);
      await _save(fullName: name);
    }
  }

  Future<void> _showAccountOption(String title) async {
    var message = switch (title) {
      'Help & support' => 'Get help with an appointment or your account.',
      _ => 'Your privacy settings are up to date.',
    };
    if (title == 'Saved businesses') {
      try {
        final saved = await _backend.savedProviders();
        message = saved.isEmpty
            ? 'You have not saved any businesses yet.'
            : saved.map((provider) => provider.name).join('\n');
      } on BackendException catch (error) {
        message = error.message;
      }
      if (!mounted) return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _logOut() async {
    try {
      await _backend.signOut();
    } on BackendException catch (error) {
      _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AudienceSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
          sliver: SliverList.list(
            children: [
              const Text(
                'YOUR SLOT',
                style: TextStyle(
                  color: Color(0xFF9A938D),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFEDE5DC),
                      child: Text(
                        _initials(_name),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.phoneNumber,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      onPressed: _editProfile,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const _SectionLabel('PREFERENCES'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    _PreferenceRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Appointment reminders',
                      subtitle: 'Get a heads-up before your visit',
                      value: _remindersEnabled,
                      onChanged: (value) {
                        setState(() => _remindersEnabled = value);
                        _save(remindersEnabled: value);
                      },
                    ),
                    const Divider(height: 1, indent: 55),
                    _PreferenceRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'WhatsApp updates',
                      subtitle: 'Helpful messages from your businesses',
                      value: _whatsAppEnabled,
                      onChanged: (value) {
                        setState(() => _whatsAppEnabled = value);
                        _save(whatsappUpdates: value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const _SectionLabel('ACCOUNT'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    _AccountRow(
                      title: 'Saved businesses',
                      onTap: () => _showAccountOption('Saved businesses'),
                    ),
                    const Divider(height: 1),
                    _AccountRow(
                      title: 'Help & support',
                      onTap: () => _showAccountOption('Help & support'),
                    ),
                    const Divider(height: 1),
                    _AccountRow(
                      title: 'Privacy',
                      onTap: () => _showAccountOption('Privacy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextButton.icon(
                onPressed: _logOut,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF9A938D),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.orange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.ink, fontSize: 15),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF918A84),
        ),
      ),
    );
  }
}
