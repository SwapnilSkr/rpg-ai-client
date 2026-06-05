/// Player gender from onboarding; `null` when skipped (neutral avatar).
enum PlayerGender { male, female, nonBinary }

PlayerGender? playerGenderFromJson(String? raw) {
  return switch (raw) {
    'male' => PlayerGender.male,
    'female' => PlayerGender.female,
    'non_binary' => PlayerGender.nonBinary,
    _ => null,
  };
}

String? playerGenderToJson(PlayerGender? gender) {
  return switch (gender) {
    PlayerGender.male => 'male',
    PlayerGender.female => 'female',
    PlayerGender.nonBinary => 'non_binary',
    null => null,
  };
}

class UserPreferences {
  final bool nsfwEnabled;
  final String preferredModel;
  final String theme;
  final String narrationLength;
  final bool autoMemoryCuration;
  /// Display name chosen during post-auth onboarding.
  final String playerName;
  /// Optional gender from onboarding; unset when skipped.
  final PlayerGender? gender;
  /// Genre taste from onboarding (`narrative_style` keys); persisted on server.
  final List<String> interests;

  const UserPreferences({
    this.nsfwEnabled = false,
    this.preferredModel = 'gpt-4o',
    this.theme = 'dark',
    this.narrationLength = 'detailed',
    this.autoMemoryCuration = true,
    this.playerName = '',
    this.gender,
    this.interests = const [],
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final raw = json['interests'];
    final interests = raw is List
        ? raw.whereType<String>().toList()
        : const <String>[];
    return UserPreferences(
      nsfwEnabled: json['nsfw_enabled'] ?? false,
      preferredModel: json['preferred_model'] ?? 'gpt-4o',
      theme: json['theme'] ?? 'dark',
      narrationLength: json['narration_length'] ?? 'detailed',
      autoMemoryCuration: json['auto_memory_curation'] ?? true,
      playerName: (json['player_name'] as String?)?.trim() ?? '',
      gender: playerGenderFromJson(json['gender'] as String?),
      interests: interests,
    );
  }

  Map<String, dynamic> toJson() => {
    'nsfw_enabled': nsfwEnabled,
    'preferred_model': preferredModel,
    'theme': theme,
    'narration_length': narrationLength,
    'auto_memory_curation': autoMemoryCuration,
    if (playerName.isNotEmpty) 'player_name': playerName,
    if (gender != null) 'gender': playerGenderToJson(gender),
    if (interests.isNotEmpty) 'interests': interests,
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
