class UserPreferences {
  final bool nsfwEnabled;
  final String preferredModel;
  final String theme;
  final String narrationLength;
  final bool autoMemoryCuration;

  const UserPreferences({
    this.nsfwEnabled = false,
    this.preferredModel = 'gpt-4o',
    this.theme = 'dark',
    this.narrationLength = 'detailed',
    this.autoMemoryCuration = true,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      nsfwEnabled: json['nsfw_enabled'] ?? false,
      preferredModel: json['preferred_model'] ?? 'gpt-4o',
      theme: json['theme'] ?? 'dark',
      narrationLength: json['narration_length'] ?? 'detailed',
      autoMemoryCuration: json['auto_memory_curation'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'nsfw_enabled': nsfwEnabled,
    'preferred_model': preferredModel,
    'theme': theme,
    'narration_length': narrationLength,
    'auto_memory_curation': autoMemoryCuration,
  };
}

class User {
  final String id;
  final String email;
  final String? phone;
  final String username;
  final String tier;
  final UserPreferences preferences;
  final int? tokenBalance;

  const User({
    required this.id,
    required this.email,
    this.phone,
    required this.username,
    required this.tier,
    this.preferences = const UserPreferences(),
    this.tokenBalance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      username: json['username'] ?? '',
      tier: json['tier'] ?? 'free',
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : const UserPreferences(),
      tokenBalance: json['token_balance'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'username': username,
    'tier': tier,
    'preferences': preferences.toJson(),
    'token_balance': tokenBalance,
  };
}
