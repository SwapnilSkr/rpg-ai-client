import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

/// Why a player is reporting something.
///
/// The wire values are the server's enum; [label] and [blurb] are what a player
/// actually reads, so they are written in the app's own register rather than as
/// policy language.
enum ReportReason {
  minorSafety(
    'sexual_content_involving_minors',
    'Sexual content involving minors',
    'Anyone written or depicted as under 18 in a sexual situation.',
  ),
  nonConsensual(
    'non_consensual_sexual_content',
    'Non-consensual sexual content',
    'Sexual content that ignores or overrides consent.',
  ),
  harassment(
    'harassment_or_hate',
    'Harassment or hate',
    'Attacks on a person or a group, slurs, or targeted abuse.',
  ),
  violence(
    'violence_or_threats',
    'Violence or threats',
    'Threats against real people, or content glorifying real violence.',
  ),
  selfHarm(
    'self_harm',
    'Self-harm or suicide',
    'Content encouraging someone to hurt themselves.',
  ),
  illegal(
    'illegal_content',
    'Illegal content',
    'Content that breaks the law where you or others live.',
  ),
  spam(
    'spam_or_misleading',
    'Spam or misleading',
    'Advertising, scams, or a world that is not what it claims to be.',
  ),
  other('other', 'Something else', 'Tell us what is wrong in your own words.');

  const ReportReason(this.wire, this.label, this.blurb);

  final String wire;
  final String label;
  final String blurb;
}

/// A creator this player has blocked.
class BlockedCreator {
  final String id;
  final String username;

  const BlockedCreator({required this.id, required this.username});

  factory BlockedCreator.fromJson(Map<String, dynamic> json) => BlockedCreator(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? 'Unknown',
  );
}

/// A single world this player has hidden.
class BlockedWorld {
  final String id;
  final String title;
  final String imageUrl;

  const BlockedWorld({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  factory BlockedWorld.fromJson(Map<String, dynamic> json) => BlockedWorld(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Untitled world',
    imageUrl: json['image_url'] as String? ?? '',
  );
}

class BlockedContent {
  final List<BlockedCreator> creators;
  final List<BlockedWorld> worlds;

  const BlockedContent({required this.creators, required this.worlds});

  bool get isEmpty => creators.isEmpty && worlds.isEmpty;

  static const empty = BlockedContent(creators: [], worlds: []);
}

/// Reporting and blocking.
///
/// Blocks are mirrored locally as well as sent to the server: discovery lists
/// are cached, so a freshly blocked world has to disappear from the list the
/// player is looking at without waiting for a refetch.
class ModerationRepository {
  static final Set<String> _blockedWorldIds = {};
  static final Set<String> _blockedCreatorIds = {};

  /// Bumped whenever the block set changes.
  ///
  /// List screens live inside a persistent IndexedStack, so returning to one
  /// after blocking something does not rebuild it — without this the blocked
  /// world stays on screen until the tab is rebuilt for some other reason.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void _bump() => revision.value++;

  /// Worlds hidden locally this session, so list screens can filter optimistically.
  static bool isHidden({required String worldId, required String creatorId}) =>
      _blockedWorldIds.contains(worldId) || _blockedCreatorIds.contains(creatorId);

  static void clearLocalBlocks() {
    _blockedWorldIds.clear();
    _blockedCreatorIds.clear();
    _bump();
  }

  static Future<void> report({
    required String targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    await ApiClient.post(
      '/moderation/reports',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason.wire,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }

  static Future<void> blockWorld(String worldId) async {
    await ApiClient.post(
      '/moderation/blocks',
      body: {'target_type': 'world', 'target_id': worldId},
    );
    _blockedWorldIds.add(worldId);
    _bump();
  }

  static Future<void> blockCreator(String creatorId) async {
    await ApiClient.post(
      '/moderation/blocks',
      body: {'target_type': 'user', 'target_id': creatorId},
    );
    _blockedCreatorIds.add(creatorId);
    _bump();
  }

  static Future<void> unblockWorld(String worldId) async {
    await ApiClient.delete('/moderation/blocks/world/$worldId');
    _blockedWorldIds.remove(worldId);
    _bump();
  }

  static Future<void> unblockCreator(String creatorId) async {
    await ApiClient.delete('/moderation/blocks/user/$creatorId');
    _blockedCreatorIds.remove(creatorId);
    _bump();
  }

  static Future<BlockedContent> listBlocks() async {
    final response = await ApiClient.get('/moderation/blocks');
    final creators = ((response['users'] as List?) ?? const [])
        .map((e) => BlockedCreator.fromJson(e as Map<String, dynamic>))
        .toList();
    final worlds = ((response['worlds'] as List?) ?? const [])
        .map((e) => BlockedWorld.fromJson(e as Map<String, dynamic>))
        .toList();

    // Keep the local mirror honest with the server on every visit to the
    // blocked-content screen — that is where a stale mirror would show.
    _blockedCreatorIds
      ..clear()
      ..addAll(creators.map((c) => c.id));
    _blockedWorldIds
      ..clear()
      ..addAll(worlds.map((w) => w.id));
    _bump();

    return BlockedContent(creators: creators, worlds: worlds);
  }
}
