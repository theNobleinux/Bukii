enum UserRole {
  customer('customer'),
  businessOwner('business_owner');

  const UserRole(this.apiValue);

  final String apiValue;

  static UserRole fromApi(String? value) =>
      value == 'business_owner' ? businessOwner : customer;

  /// Maps the audience picked on the welcome screen.
  static UserRole fromAudience(String audience) =>
      audience.toLowerCase().contains('business') ? businessOwner : customer;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.remindersEnabled = true,
    this.whatsappUpdates = false,
  });

  final String id;
  final UserRole role;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final bool remindersEnabled;
  final bool whatsappUpdates;

  String get firstName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    role: UserRole.fromApi(json['role'] as String?),
    fullName: json['full_name'] as String?,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    remindersEnabled: json['reminders_enabled'] as bool? ?? true,
    whatsappUpdates: json['whatsapp_updates'] as bool? ?? false,
  );

  UserProfile copyWith({
    String? fullName,
    bool? remindersEnabled,
    bool? whatsappUpdates,
  }) => UserProfile(
    id: id,
    role: role,
    fullName: fullName ?? this.fullName,
    phone: phone,
    avatarUrl: avatarUrl,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    whatsappUpdates: whatsappUpdates ?? this.whatsappUpdates,
  );
}
