import 'dart:async';

import '../../../core/network/api_client.dart';
import '../../../shared/models/world_template.dart';
import '../../billing/data/billing_repository.dart';
import '../../creator/data/creator_repository.dart';
import '../models/group_draft.dart';

enum GroupFaceOutcome { ready, queued, resting, unseen }

/// What asking for a face came back as (contract §6a).
class GroupFaceResult {
  final GroupFaceOutcome outcome;

  /// The new face, when [outcome] is ready.
  final String? url;

  /// The server's own words for resting and unseen; written for players.
  final String? message;

  const GroupFaceResult(this.outcome, {this.url, this.message});
}

/// The calls for making, editing and sharing a player's group. Static, like
/// [CreatorRepository], whose cache and `changes` signal every write here
/// goes through.
class GroupCreateRepository {
  /// Asks the server to write every line from the form (`POST
  /// /templates/group-draft`). Drafting reserves Ink, so the wallet is
  /// refreshed afterwards.
  static Future<GroupDraft> draft(GroupForm form) async {
    final response = await ApiClient.post(
      '/templates/group-draft',
      body: form.toJson(),
    );
    unawaited(BillingRepository.instance.refreshInBackground());
    final map = Map<String, dynamic>.from(response as Map);
    return GroupDraft.fromDraft(Map<String, dynamic>.from(map['draft'] as Map));
  }

  /// Saves a new group; returns its id. The draft from the server already is
  /// a full create body, so its own keys (`kind`, `is_sentient`) go along.
  static Future<String> create(GroupDraft draft) async {
    final response = await ApiClient.post(
      '/templates',
      body: {'kind': 'group', ...draft.toSaveBody()},
    );
    CreatorRepository.invalidate();
    final map = Map<String, dynamic>.from(response as Map);
    final saved = map['template'] is Map ? map['template'] as Map : map;
    final id = saved['_id'] ?? saved['id'];
    if (id is! String || id.isEmpty) {
      throw ApiException(statusCode: 500, message: 'No id in the saved group');
    }
    return id;
  }

  static Future<void> update(String id, GroupDraft draft) async {
    await ApiClient.put('/templates/$id', body: draft.toSaveBody());
    CreatorRepository.invalidate();
  }

  /// A saved group read back for editing, with every line (owner only).
  static Future<GroupDraft> loadForEdit(String id) async {
    final response = await ApiClient.get('/templates/$id/authoring');
    return GroupDraft.fromAuthoring(Map<String, dynamic>.from(response as Map));
  }

  /// Asks for a person's face. The face is painted from the saved
  /// appearance, so the caller saves first. A spent allowance (422 or 429 with
  /// `status: resting`) and a refused picture (422 without one) are results,
  /// not errors; anything else throws.
  static Future<GroupFaceResult> requestFace(
    String id,
    int index, {
    bool repaint = false,
  }) async {
    final path = '/templates/$id/cast/$index/portrait';
    try {
      final response = await ApiClient.post(
        repaint ? '$path?repaint=true' : path,
      );
      final map = response is Map ? response : const {};
      CreatorRepository.invalidate();
      if (map['status'] == 'ready') {
        final url = map['url'];
        return GroupFaceResult(
          GroupFaceOutcome.ready,
          url: url is String ? url : null,
        );
      }
      return const GroupFaceResult(GroupFaceOutcome.queued);
    } on ApiException catch (e) {
      if (e.statusCode != 422 && e.statusCode != 429) rethrow;
      final resting = e.details?['status'] == 'resting';
      if (!resting && e.statusCode == 429) rethrow;
      return GroupFaceResult(
        resting ? GroupFaceOutcome.resting : GroupFaceOutcome.unseen,
        message: e.message,
      );
    }
  }

  /// "Your groups": only the player's groups, never worlds.
  static Future<CreatorWorldPage> listMine({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await ApiClient.get(
      '/templates/mine/list?kind=group&page=$page&limit=$limit',
    );
    final map = Map<String, dynamic>.from(response as Map);
    final rows = [
      for (final e in (map['templates'] as List?) ?? const [])
        if (e is Map) WorldTemplate.fromJson(Map<String, dynamic>.from(e)),
    ];
    return CreatorWorldPage(
      worlds: rows,
      total: (map['total'] as num?)?.toInt() ?? rows.length,
      page: (map['page'] as num?)?.toInt() ?? page,
    );
  }

  static Future<void> publish(String id, String visibility) async {
    await CreatorRepository.publish(id, visibility: visibility);
  }

  static Future<void> delete(String id) => CreatorRepository.delete(id);
}
