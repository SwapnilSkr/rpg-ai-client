import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../models/group_draft.dart';

enum CreateGroupPhase { form, drafting, loading, editing }

enum GroupFaceStatus { idle, painting, ready, resting, unseen }

/// Where one person's face stands. [message] is the server's own words for
/// resting and unseen, or ours when a wait ran out.
class GroupFace extends Equatable {
  final GroupFaceStatus status;
  final String? message;

  const GroupFace(this.status, {this.message});

  static const idle = GroupFace(GroupFaceStatus.idle);

  @override
  List<Object?> get props => [status, message];
}

class CreateGroupState extends Equatable {
  final CreateGroupPhase phase;
  final GroupForm form;

  /// Field errors of the form, keyed `title`, `people.1.age`, ...
  final Map<String, String> formErrors;

  /// The group being edited; null until drafted or loaded.
  final GroupDraft? draft;

  /// What the server last gave back (drafted, or read after a save): the
  /// baseline for [isDirty] and [faceWillReset].
  final GroupDraft? saved;

  /// What stops a save before anything is sent, by path, with a message for
  /// the player (`GroupDraft.validate`); editing that field clears it.
  final Map<String, String> fieldErrors;

  /// Paths the server refused on the last save (`seed_cast.2.voice.4`);
  /// editing that field clears its path.
  final Set<String> refusedPaths;

  /// Per-person face status, by cast index; absent means idle.
  final Map<int, GroupFace> faces;

  final bool isSaving;
  final bool isPublishing;
  final bool isDeleting;
  final bool isDeleted;

  /// A message for the player, in plain words; null when there is none.
  final String? error;

  const CreateGroupState({
    this.phase = CreateGroupPhase.form,
    this.form = const GroupForm(),
    this.formErrors = const {},
    this.draft,
    this.saved,
    this.fieldErrors = const {},
    this.refusedPaths = const {},
    this.faces = const {},
    this.isSaving = false,
    this.isPublishing = false,
    this.isDeleting = false,
    this.isDeleted = false,
    this.error,
  });

  CreateGroupState copyWith({
    CreateGroupPhase? phase,
    GroupForm? form,
    Map<String, String>? formErrors,
    GroupDraft? draft,
    GroupDraft? saved,
    bool clearDraft = false,
    Map<String, String>? fieldErrors,
    Set<String>? refusedPaths,
    Map<int, GroupFace>? faces,
    bool? isSaving,
    bool? isPublishing,
    bool? isDeleting,
    bool? isDeleted,
    String? error,
    bool clearError = false,
  }) => CreateGroupState(
    phase: phase ?? this.phase,
    form: form ?? this.form,
    formErrors: formErrors ?? this.formErrors,
    draft: clearDraft ? null : (draft ?? this.draft),
    saved: clearDraft ? null : (saved ?? this.saved),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    refusedPaths: refusedPaths ?? this.refusedPaths,
    faces: faces ?? this.faces,
    isSaving: isSaving ?? this.isSaving,
    isPublishing: isPublishing ?? this.isPublishing,
    isDeleting: isDeleting ?? this.isDeleting,
    isDeleted: isDeleted ?? this.isDeleted,
    error: clearError ? null : (error ?? this.error),
  );

  /// True while a call that replaces the draft is running; edits wait.
  bool get isBusy => isSaving || isPublishing || isDeleting;

  GroupFace faceOf(int index) => faces[index] ?? GroupFace.idle;

  /// Edited since it was last saved or drafted.
  bool get isDirty {
    final d = draft;
    final s = saved;
    if (d == null || s == null) return false;
    return jsonEncode(d.toSaveBody()) != jsonEncode(s.toSaveBody());
  }

  /// A group with no id has never been saved, edited or not.
  bool get needsSave => draft != null && (draft!.id == null || isDirty);

  /// The person had a face at the last save and their name or look now
  /// differs: the server drops that face on the next save (§6a).
  bool faceWillReset(int index) {
    final d = draft;
    final s = saved;
    if (d == null || s == null) return false;
    if (index < 0 || index >= d.cast.length || index >= s.cast.length) {
      return false;
    }
    final was = s.cast[index];
    final now = d.cast[index];
    return was.portraitUrl.isNotEmpty &&
        (was.name.trim() != now.name.trim() ||
            was.appearance.trim() != now.appearance.trim());
  }

  /// A face the person will still have after a save.
  bool hasFace(int index) =>
      index >= 0 &&
      draft != null &&
      index < draft!.cast.length &&
      draft!.cast[index].portraitUrl.isNotEmpty &&
      !faceWillReset(index);

  bool get everyoneHasFace =>
      draft != null &&
      draft!.cast.isNotEmpty &&
      [for (var i = 0; i < draft!.cast.length; i++) i].every(hasFace);

  @override
  List<Object?> get props => [
    phase,
    form,
    formErrors,
    draft,
    saved,
    fieldErrors,
    refusedPaths,
    faces,
    isSaving,
    isPublishing,
    isDeleting,
    isDeleted,
    error,
  ];
}
