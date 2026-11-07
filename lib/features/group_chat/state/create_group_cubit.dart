import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/group_create_repository.dart';
import '../models/group_draft.dart';
import 'create_group_state.dart';

/// The whole make-a-group flow in one place: the form, the draft, reading and
/// editing it, saving, faces, publishing. Every call is injected so tests run
/// without a network.
class CreateGroupCubit extends Cubit<CreateGroupState> {
  static const faceMissingMessage =
      'Every person needs a face before this group can be shared.';
  static const faceSlowMessage =
      'This is taking longer than usual. Try again in a while.';
  static const retryMessage = 'Try again in a moment.';
  static const checkMessage =
      "Some lines in this group can't be saved. Check each part and try again.";

  final Future<GroupDraft> Function(GroupForm form) _draftFn;
  final Future<String> Function(GroupDraft draft) _createFn;
  final Future<void> Function(String id, GroupDraft draft) _updateFn;
  final Future<GroupDraft> Function(String id) _loadFn;
  final Future<GroupFaceResult> Function(String id, int index, {bool repaint})
  _faceFn;
  final Future<void> Function(String id, String visibility) _publishFn;
  final Future<void> Function(String id) _deleteFn;
  final Future<void> Function(Duration) _delay;

  /// A face is re-read every [pollEvery] for up to [pollFor].
  final Duration pollEvery;
  final Duration pollFor;

  String? _loadingId;

  CreateGroupCubit({
    Future<GroupDraft> Function(GroupForm form)? draftFn,
    Future<String> Function(GroupDraft draft)? createFn,
    Future<void> Function(String id, GroupDraft draft)? updateFn,
    Future<GroupDraft> Function(String id)? loadFn,
    Future<GroupFaceResult> Function(String id, int index, {bool repaint})?
    faceFn,
    Future<void> Function(String id, String visibility)? publishFn,
    Future<void> Function(String id)? deleteFn,
    Future<void> Function(Duration)? delay,
    this.pollEvery = const Duration(seconds: 4),
    this.pollFor = const Duration(minutes: 2),
  }) : _draftFn = draftFn ?? GroupCreateRepository.draft,
       _createFn = createFn ?? GroupCreateRepository.create,
       _updateFn = updateFn ?? GroupCreateRepository.update,
       _loadFn = loadFn ?? GroupCreateRepository.loadForEdit,
       _faceFn = faceFn ?? GroupCreateRepository.requestFace,
       _publishFn = publishFn ?? GroupCreateRepository.publish,
       _deleteFn = deleteFn ?? GroupCreateRepository.delete,
       _delay = delay ?? Future<void>.delayed,
       super(const CreateGroupState());

  // ---- the form ----------------------------------------------------------

  void updateForm({String? title, String? setting, bool? adult}) {
    if (state.phase != CreateGroupPhase.form) return;
    emit(
      state.copyWith(
        form: state.form.copyWith(title: title, setting: setting, adult: adult),
        formErrors: _clearedForm([
          if (title != null) 'title',
          if (setting != null) 'setting',
        ]),
      ),
    );
  }

  void updatePerson(int index, GroupFormPerson person) {
    final people = state.form.people;
    if (state.phase != CreateGroupPhase.form ||
        index < 0 ||
        index >= people.length) {
      return;
    }
    emit(
      state.copyWith(
        form: state.form.copyWith(
          people: [
            for (var i = 0; i < people.length; i++)
              i == index ? person : people[i],
          ],
        ),
        // A name change can fix or cause a duplicate in another row.
        formErrors: _clearedForm(['people.$index', 'people.', 'people']),
      ),
    );
  }

  void addPerson() {
    final people = state.form.people;
    if (state.phase != CreateGroupPhase.form ||
        people.length >= GroupForm.maxPeople) {
      return;
    }
    emit(
      state.copyWith(
        form: state.form.copyWith(people: [...people, const GroupFormPerson()]),
        formErrors: const {},
      ),
    );
  }

  void removePerson(int index) {
    final people = state.form.people;
    if (state.phase != CreateGroupPhase.form ||
        people.length <= GroupForm.minPeople ||
        index < 0 ||
        index >= people.length) {
      return;
    }
    emit(
      state.copyWith(
        form: state.form.copyWith(
          people: [
            for (var i = 0; i < people.length; i++)
              if (i != index) people[i],
          ],
        ),
        formErrors: const {},
      ),
    );
  }

  /// Errors left after editing [fields]; a field ending in `.` clears every
  /// duplicate-name error, so editing one name re-judges the rest on send.
  Map<String, String> _clearedForm(List<String> fields) => {
    for (final e in state.formErrors.entries)
      if (!fields.any(
        (f) => e.key == f || (f != 'people.' && e.key.startsWith('$f.')),
      ))
        e.key: e.value,
  };

  void backToForm() {
    if (state.phase != CreateGroupPhase.editing || state.draft?.id != null) {
      return;
    }
    emit(
      state.copyWith(
        phase: CreateGroupPhase.form,
        clearDraft: true,
        refusedPaths: const {},
        faces: const {},
        clearError: true,
      ),
    );
  }

  // ---- drafting and loading ----------------------------------------------

  Future<void> draft() async {
    if (state.phase != CreateGroupPhase.form) return;
    final errors = state.form.validate();
    if (errors.isNotEmpty) {
      emit(state.copyWith(formErrors: errors, clearError: true));
      return;
    }
    emit(
      state.copyWith(
        phase: CreateGroupPhase.drafting,
        formErrors: const {},
        clearError: true,
      ),
    );
    try {
      final drafted = await _draftFn(state.form);
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: CreateGroupPhase.editing,
          draft: drafted,
          saved: drafted,
          refusedPaths: const {},
          faces: const {},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(phase: CreateGroupPhase.form, error: _message(e)));
    }
  }

  /// Opens a saved group for editing. A failed load leaves the phase at
  /// `loading` with [CreateGroupState.error] set; call again to retry.
  Future<void> load(String id) async {
    _loadingId = id;
    emit(const CreateGroupState(phase: CreateGroupPhase.loading));
    try {
      final loaded = await _loadFn(id);
      if (isClosed || _loadingId != id) return;
      emit(
        CreateGroupState(
          phase: CreateGroupPhase.editing,
          draft: loaded,
          saved: loaded,
        ),
      );
    } catch (e) {
      if (isClosed || _loadingId != id) return;
      emit(
        const CreateGroupState(
          phase: CreateGroupPhase.loading,
        ).copyWith(error: _message(e)),
      );
    }
  }

  // ---- editing -----------------------------------------------------------

  bool get _canEdit =>
      state.phase == CreateGroupPhase.editing &&
      state.draft != null &&
      !state.isBusy;

  /// Paths left after an edit under [path]: that path and everything below it.
  bool _under(String p, String path) => p == path || p.startsWith('$path.');

  Set<String> _clearedPaths(String path) => {
    for (final p in state.refusedPaths)
      if (!_under(p, path)) p,
  };

  Map<String, String> _clearedErrors(String path) => {
    for (final e in state.fieldErrors.entries)
      if (!_under(e.key, path)) e.key: e.value,
  };

  void _edit(GroupDraft Function(GroupDraft d) change, String path) {
    if (!_canEdit) return;
    emit(
      state.copyWith(
        draft: change(state.draft!),
        refusedPaths: _clearedPaths(path),
        fieldErrors: _clearedErrors(path),
      ),
    );
  }

  /// [field] is relative to the person and spelled as the text gate spells
  /// it (`group.voice`, `first_texts`, `name`).
  void _editPerson(
    int i,
    GroupDraftPerson Function(GroupDraftPerson p) change,
    String field,
  ) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.cast.length) return;
    _edit((d) => d.withPerson(i, change(d.cast[i])), 'seed_cast.$i.$field');
  }

  void setTitle(String v) => _edit((d) => d.copyWith(title: v), 'title');
  void setDescription(String v) =>
      _edit((d) => d.copyWith(description: v), 'description');
  void setSeedPrompt(String v) =>
      _edit((d) => d.copyWith(seedPrompt: v), 'seed_prompt');
  void setGlobalLore(String v) =>
      _edit((d) => d.copyWith(globalLore: v), 'global_lore');
  void setAdult(bool v) =>
      _edit((d) => d.copyWith(isNsfwCapable: v), 'is_nsfw_capable');

  void setTopic(int i, String v) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.topics.length) return;
    _edit((d) => d.copyWith(topics: _replaced(d.topics, i, v)), 'topics.$i');
  }

  void addTopic() =>
      _edit((d) => d.copyWith(topics: [...d.topics, '']), 'topics');

  void removeTopic(int i) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.topics.length) return;
    _edit((d) => d.copyWith(topics: _removed(d.topics, i)), 'topics');
  }

  void setOpeningText(int i, String v) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.openingLines.length) return;
    _edit(
      (d) => d.copyWith(
        openingLines: _replaced(
          d.openingLines,
          i,
          d.openingLines[i].copyWith(text: v),
        ),
      ),
      'opening_lines.$i',
    );
  }

  void setOpeningSpeaker(int i, String name) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.openingLines.length) return;
    _edit(
      (d) => d.copyWith(
        openingLines: _replaced(
          d.openingLines,
          i,
          d.openingLines[i].copyWith(name: name),
        ),
      ),
      'opening_lines.$i',
    );
  }

  void addOpeningLine() {
    final d = state.draft;
    if (d == null || d.cast.isEmpty) return;
    _edit(
      (d) => d.copyWith(
        openingLines: [
          ...d.openingLines,
          GroupOpeningLine(name: d.cast.first.name, text: ''),
        ],
      ),
      'opening_lines',
    );
  }

  void removeOpeningLine(int i) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.openingLines.length) return;
    _edit(
      (d) => d.copyWith(openingLines: _removed(d.openingLines, i)),
      'opening_lines',
    );
  }

  /// Renames the person everywhere they speak in the opening conversation.
  void setPersonName(int i, String v) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.cast.length) return;
    _edit((d) => d.renamePerson(i, v), 'seed_cast.$i.name');
    // A new name can fix or cause a duplicate or an unnamed opening line.
    if (state.fieldErrors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: const {}));
    }
  }

  void setPersonRole(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(role: v), 'role');
  void setPersonAppearance(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(appearance: v), 'appearance');
  void setPersonPersona(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(persona: v), 'persona');
  void setPersonAge(int i, int v) =>
      _editPerson(i, (p) => p.copyWith(age: v), 'group.age');
  void setPersonTalkativeness(int i, double v) => _editPerson(
    i,
    (p) => p.copyWith(talkativeness: v.clamp(0.0, 1.0)),
    'group.talkativeness',
  );
  void setPersonSpeech(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(speech: v), 'group.speech');
  void setPersonWants(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(wants: v), 'group.wants');
  void setPersonIntimacy(int i, String v) =>
      _editPerson(i, (p) => p.copyWith(intimacy: v), 'group.intimacy');
  void setPersonStartBond(int i, GroupCloseness v) =>
      _editPerson(i, (p) => p.copyWith(startBond: v.wire), 'group.start_bond');

  void setVoiceLine(int i, int j, String v) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.cast.length) return;
    if (j < 0 || j >= d.cast[i].voice.length) return;
    _editPerson(
      i,
      (p) => p.copyWith(voice: _replaced(p.voice, j, v)),
      'group.voice.$j',
    );
  }

  void addVoiceLine(int i) =>
      _editPerson(i, (p) => p.copyWith(voice: [...p.voice, '']), 'group.voice');

  void removeVoiceLine(int i, int j) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.cast.length) return;
    if (j < 0 || j >= d.cast[i].voice.length) return;
    _editPerson(
      i,
      (p) => p.copyWith(voice: _removed(p.voice, j)),
      'group.voice',
    );
  }

  void setFirstText(int i, int j, String v) {
    final d = state.draft;
    if (d == null || i < 0 || i >= d.cast.length) return;
    if (j < 0 || j >= d.cast[i].firstTexts.length) return;
    _editPerson(
      i,
      (p) => p.copyWith(firstTexts: _replaced(p.firstTexts, j, v)),
      'first_texts.$j',
    );
  }

  /// [period] is one of [GroupDraftPerson.periods].
  void setStatus(int i, String period, String v) {
    if (!GroupDraftPerson.periods.contains(period)) return;
    _editPerson(
      i,
      (p) => p.copyWith(statuses: {...p.statuses, period: v}),
      'statuses.$period',
    );
  }

  static List<T> _replaced<T>(List<T> list, int i, T v) => [
    for (var k = 0; k < list.length; k++) k == i ? v : list[k],
  ];

  static List<T> _removed<T>(List<T> list, int i) => [
    for (var k = 0; k < list.length; k++)
      if (k != i) list[k],
  ];

  bool get isDirty => state.isDirty;

  bool faceWillReset(int i) => state.faceWillReset(i);

  // ---- saving ------------------------------------------------------------

  /// Creates the group, or updates it with the full cast. One save at a time:
  /// a second call while one runs does nothing. The state ends holding the
  /// server's copy, so faces and URLs are current.
  Future<bool> save() async {
    final d = state.draft;
    if (d == null || state.isBusy) return false;
    // The server's structure check is not for players: find what it would
    // refuse here, say so on the fields, and send nothing.
    final problems = d.validate();
    if (problems.isNotEmpty) {
      emit(
        state.copyWith(
          fieldErrors: problems,
          refusedPaths: const {},
          error: checkMessage,
        ),
      );
      return false;
    }
    emit(
      state.copyWith(
        isSaving: true,
        fieldErrors: const {},
        refusedPaths: const {},
        clearError: true,
      ),
    );
    final String id;
    try {
      final known = d.id;
      if (known == null) {
        id = await _createFn(d);
      } else {
        await _updateFn(known, d);
        id = known;
      }
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          // A 400 is the server's structure check, written for developers.
          error: e is ApiException && e.statusCode == 400
              ? checkMessage
              : _message(e),
          refusedPaths: _refusedPaths(e),
        ),
      );
      return false;
    }
    if (isClosed) return false;
    GroupDraft fresh;
    try {
      fresh = await _loadFn(id);
    } catch (_) {
      // Saved, but the re-read failed: keep what was sent, with its id, so a
      // retry updates the group instead of creating a second one.
      fresh = d.copyWith(id: id);
    }
    if (isClosed) return false;
    emit(state.copyWith(isSaving: false, draft: fresh, saved: fresh));
    return true;
  }

  // ---- faces -------------------------------------------------------------

  void _setFace(int index, GroupFace face) =>
      emit(state.copyWith(faces: {...state.faces, index: face}));

  /// Asks for a face for person [index]. Unsaved changes are saved first,
  /// because the face is painted from the saved look; if that fails nothing
  /// is asked.
  Future<void> requestFace(int index, {bool repaint = false}) async {
    final d = state.draft;
    if (d == null || index < 0 || index >= d.cast.length) return;
    if (state.isBusy ||
        state.faceOf(index).status == GroupFaceStatus.painting) {
      return;
    }
    // Set before the first await, so a second tap is the guard's, and so is
    // the one poll per person.
    _setFace(index, const GroupFace(GroupFaceStatus.painting));
    if (state.needsSave) {
      final ok = await save();
      if (isClosed) return;
      if (!ok) {
        _setFace(index, GroupFace.idle);
        return;
      }
    }
    final saved = state.saved;
    final id = saved?.id;
    if (saved == null || id == null || index >= saved.cast.length) {
      _setFace(index, GroupFace.idle);
      return;
    }
    final name = saved.cast[index].name;
    final before = saved.cast[index].portraitUrl;
    try {
      final result = await _faceFn(id, index, repaint: repaint);
      if (isClosed) return;
      switch (result.outcome) {
        case GroupFaceOutcome.ready:
          await _faceReady(id, index, result.url);
        case GroupFaceOutcome.queued:
          await _poll(id, index, name, before);
        case GroupFaceOutcome.resting:
          _setFace(
            index,
            GroupFace(GroupFaceStatus.resting, message: result.message),
          );
        case GroupFaceOutcome.unseen:
          _setFace(
            index,
            GroupFace(GroupFaceStatus.unseen, message: result.message),
          );
      }
    } catch (e) {
      if (isClosed) return;
      _setFace(index, GroupFace.idle);
      emit(state.copyWith(error: _message(e)));
    }
  }

  Future<void> _faceReady(String id, int index, String? url) async {
    try {
      _mergeFaces(await _loadFn(id));
    } catch (_) {
      if (url != null) _patchFace(index, url);
    }
    if (isClosed) return;
    _setFace(index, const GroupFace(GroupFaceStatus.ready));
  }

  /// Re-reads the group until person [index] has a face other than [before],
  /// giving up after [pollFor]. Stops quietly when the group is closed, the
  /// person is gone or renamed, or the group on screen is another one.
  Future<void> _poll(String id, int index, String name, String before) async {
    final tries = pollFor.inMilliseconds ~/ pollEvery.inMilliseconds;
    for (var n = 0; n < tries; n++) {
      await _delay(pollEvery);
      if (isClosed) return;
      if (!_stillPainting(id, index, name)) return _stopPolling(id, index);
      try {
        final fresh = await _loadFn(id);
        if (isClosed) return;
        if (!_stillPainting(id, index, name)) return _stopPolling(id, index);
        final url = index < fresh.cast.length
            ? fresh.cast[index].portraitUrl
            : '';
        if (url.isNotEmpty && url != before) {
          _mergeFaces(fresh);
          _setFace(index, const GroupFace(GroupFaceStatus.ready));
          return;
        }
      } catch (_) {
        // One failed read is not the end of a two-minute wait.
      }
    }
    if (isClosed || !_stillPainting(id, index, name)) return;
    _setFace(index, GroupFace.idle);
    emit(state.copyWith(error: faceSlowMessage));
  }

  bool _stillPainting(String id, int index, String name) {
    final d = state.draft;
    return d != null &&
        d.id == id &&
        index < d.cast.length &&
        d.cast[index].name.trim() == name.trim() &&
        state.faceOf(index).status == GroupFaceStatus.painting;
  }

  void _stopPolling(String id, int index) {
    if (state.draft?.id == id &&
        state.faceOf(index).status == GroupFaceStatus.painting) {
      _setFace(index, GroupFace.idle);
    }
  }

  void _mergeFaces(GroupDraft fresh) {
    final d = state.draft;
    final s = state.saved;
    if (d == null || s == null || d.id != fresh.id) return;
    emit(
      state.copyWith(
        draft: d.withFacesFrom(fresh),
        saved: s.withFacesFrom(fresh),
      ),
    );
  }

  void _patchFace(int index, String url) {
    final d = state.draft;
    final s = state.saved;
    if (d == null || s == null) return;
    GroupDraft patch(GroupDraft g) => index < g.cast.length
        ? g.withPerson(index, g.cast[index].copyWith(portraitUrl: url))
        : g;
    emit(state.copyWith(draft: patch(d), saved: patch(s)));
  }

  // ---- publishing and deleting -------------------------------------------

  /// [visibility] is `private` or `public`. Public needs a face on every
  /// person, checked here before anything is sent; the server checks too.
  Future<bool> publish(String visibility) async {
    final d = state.draft;
    if (d == null || state.isBusy) return false;
    if (visibility == 'public' && !state.everyoneHasFace) {
      emit(state.copyWith(error: faceMissingMessage));
      return false;
    }
    if (state.needsSave) {
      if (!await save()) return false;
      if (isClosed) return false;
    }
    final id = state.draft?.id;
    if (id == null) return false;
    emit(state.copyWith(isPublishing: true, clearError: true));
    try {
      await _publishFn(id, visibility);
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPublishing: false,
          error: _message(e),
          refusedPaths: _refusedPaths(e),
        ),
      );
      return false;
    }
    if (isClosed) return false;
    try {
      final fresh = await _loadFn(id);
      if (isClosed) return false;
      emit(state.copyWith(isPublishing: false, draft: fresh, saved: fresh));
    } catch (_) {
      if (isClosed) return false;
      emit(state.copyWith(isPublishing: false));
    }
    return true;
  }

  Future<bool> delete() async {
    final id = state.draft?.id;
    if (id == null || state.isBusy) return false;
    emit(state.copyWith(isDeleting: true, clearError: true));
    try {
      await _deleteFn(id);
      if (isClosed) return false;
      emit(state.copyWith(isDeleting: false, isDeleted: true));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isDeleting: false, error: _message(e)));
      return false;
    }
  }

  /// The lines a 422 named (`seed_cast.2.voice.4`); null when it named none,
  /// which leaves the current set alone.
  static Set<String>? _refusedPaths(Object e) {
    if (e is! ApiException || e.statusCode != 422) return null;
    final paths = e.details?['paths'];
    if (paths is! List) return null;
    return {
      for (final p in paths)
        if (p is String) p,
    };
  }

  void clearError() => emit(state.copyWith(clearError: true));

  /// The server writes its refusals for players (400, 403, 422, 429, and a
  /// missing group); everything else, a 503 or a dropped connection, is the
  /// same plain retry.
  static String _message(Object e) {
    if (e is ApiException &&
        const {400, 403, 404, 422, 429}.contains(e.statusCode)) {
      return e.message;
    }
    return retryMessage;
  }
}
