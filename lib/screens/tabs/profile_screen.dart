import 'package:flutter/material.dart';

import '../../data/repositories/sample_providers.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _name = 'Amara Okafor';
  var _remindersEnabled = true;
  var _whatsAppEnabled = false;

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: _name);
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
    if (name != null && name.isNotEmpty) setState(() => _name = name);
  }

  void _showAccountOption(String title) {
    final message = switch (title) {
      'Saved businesses' =>
        sampleProviders.map((provider) => provider.name).join('\n'),
      'Help & support' => 'Get help with an appointment or your account.',
      _ => 'Your privacy settings are up to date.',
    };
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

  void _logOut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You’ve been signed out of this demo account.'),
      ),
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
                      onChanged: (value) =>
                          setState(() => _remindersEnabled = value),
                    ),
                    const Divider(height: 1, indent: 55),
                    _PreferenceRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'WhatsApp updates',
                      subtitle: 'Helpful messages from your businesses',
                      value: _whatsAppEnabled,
                      onChanged: (value) =>
                          setState(() => _whatsAppEnabled = value),
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
