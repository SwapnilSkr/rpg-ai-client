import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_closeness_picker.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_face_frame.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_fold_section.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_text_field.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';

/// Opens the editor bottom sheet for one person in the group cast.
/// Wrapped in BlocProvider.value so state and face progress stream live.
Future<void> showGroupPersonEditorSheet(
  BuildContext context, {
  required int personIndex,
  bool scrollToFirstError = false,
}) async {
  final cubit = context.read<CreateGroupCubit>();
  await showEverloreSheet(
    context: context,
    backgroundColor: EverloreTheme.void1,
    builder: (sheetContext) {
      return BlocProvider.value(
        value: cubit,
        child: BlocBuilder<CreateGroupCubit, CreateGroupState>(
          builder: (context, state) {
            return GroupPersonEditorSheet(
              personIndex: personIndex,
              scrollToFirstError: scrollToFirstError,
            );
          },
        ),
      );
    },
  );
}

/// The editor bottom sheet for one person.
/// Sized to 94% height, with a header inside the scroll view so the keyboard
/// pushes it up, all individual fields with their limits and error homes,
/// and a pinned gold Done button hidden when the keyboard is up.
class GroupPersonEditorSheet extends StatefulWidget {
  final int personIndex;
  final bool scrollToFirstError;

  const GroupPersonEditorSheet({
    super.key,
    required this.personIndex,
    this.scrollToFirstError = false,
  });

  @override
  State<GroupPersonEditorSheet> createState() => _GroupPersonEditorSheetState();
}

class _GroupPersonEditorSheetState extends State<GroupPersonEditorSheet> {
  late final ScrollController _scrollController;
  final Map<String, GlobalKey> _fieldKeys = {};
  bool _didScrollToError = false;

  int get personIndex => widget.personIndex;

  GlobalKey _keyFor(String path) =>
      _fieldKeys.putIfAbsent(path, () => GlobalKey(debugLabel: path));

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.scrollToFirstError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Wait for the fold's AnimatedSize / sheet transition to open before scrolling
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _scrollToFirstError();
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFirstError() {
    if (_didScrollToError || !mounted) return;
    final cubit = context.read<CreateGroupCubit>();
    final state = cubit.state;
    final draft = state.draft;
    if (draft == null || personIndex < 0 || personIndex >= draft.cast.length) {
      return;
    }
    final person = draft.cast[personIndex];
    final isAdult = draft.isNsfwCapable;
    final at = 'seed_cast.$personIndex';

    final orderedPaths = <String>[
      '$at.name',
      '$at.group.age',
      '$at.role',
      '$at.appearance',
      '$at.persona',
      '$at.group.speech',
      '$at.group.wants',
      '$at.group.talkativeness',
      if (isAdult) '$at.group.intimacy',
      '$at.group.voice',
      for (var j = 0; j < person.voice.length; j++) '$at.group.voice.$j',
      '$at.first_texts',
      for (var j = 0; j < 3; j++) '$at.first_texts.$j',
      '$at.statuses',
      for (final period in ['morning', 'afternoon', 'evening', 'night'])
        '$at.statuses.$period',
    ];

    for (final path in orderedPaths) {
      final isMatch =
          state.fieldErrors.containsKey(path) ||
          state.refusedPaths.contains(path) ||
          (path == '$at.group.voice' &&
              state.refusedPaths.any(
                (p) =>
                    p.startsWith('$at.group.voice.') &&
                    (int.tryParse(p.split('.').last) ?? 0) >=
                        person.voice.length,
              ));
      if (isMatch) {
        final key = _fieldKeys[path];
        if (key?.currentContext != null) {
          _didScrollToError = true;
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          return;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_didScrollToError) {
              _scrollToFirstError();
            }
          });
          return;
        }
      }
    }
  }

  String? _errorOf(CreateGroupState state, String path) {
    if (state.fieldErrors.containsKey(path)) {
      return state.fieldErrors[path];
    }
    if (state.refusedPaths.contains(path)) {
      return "This line can't be saved. Change it.";
    }
    return null;
  }

  Color _bondTone(GroupCloseness? bond) => GroupClosenessPicker.toneOf(bond);

  String _bondLabel(GroupCloseness? bond) => GroupClosenessPicker.labelOf(bond);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final state = cubit.state;
    final draft = state.draft;
    if (draft == null || personIndex < 0 || personIndex >= draft.cast.length) {
      return const SizedBox.shrink();
    }

    final person = draft.cast[personIndex];
    final isAdult = draft.isNsfwCapable;
    final isBusy = state.isBusy;
    final face = state.faceOf(personIndex);
    final faceWillReset = state.faceWillReset(personIndex);
    final at = 'seed_cast.$personIndex';

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardUp = viewInsets.bottom > 0;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Never taller than 94% of screen and bounded by keyboard viewInsets.
    final maxHeight = (screenHeight * 0.94).clamp(
      0.0,
      screenHeight - viewInsets.bottom,
    );

    final bond = GroupCloseness.fromWire(person.startBond);
    final bondTone = _bondTone(bond);
    final bondText = _bondLabel(bond);

    final ageError = _errorOf(state, '$at.group.age');

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            const SheetGrabHandle(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header (inside scroll so keyboard pushes it up)
                    _buildHeader(
                      context,
                      cubit,
                      person,
                      face,
                      faceWillReset,
                      isBusy,
                      bond,
                      bondTone,
                      bondText,
                      screenHeight,
                    ),

                    // 2. Form fields gutter 20
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + Age row (flex 5 and 2)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: GroupTextField(
                                  key: _keyFor('$at.name'),
                                  label: 'Name',
                                  hint: 'Their name…',
                                  initialValue: person.name,
                                  errorText: _errorOf(state, '$at.name'),
                                  enabled: !isBusy,
                                  maxLength: GroupFormPerson.nameMax,
                                  wrapSingleLine: true,
                                  onChanged: (val) =>
                                      cubit.setPersonName(personIndex, val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: GroupTextField(
                                  key: _keyFor('$at.group.age'),
                                  label: 'Age',
                                  hint: '18+',
                                  initialValue: person.age > 0
                                      ? person.age.toString()
                                      : '',
                                  errorText: ageError,
                                  showErrorText: false,
                                  keyboardType: TextInputType.number,
                                  maxLength: 3,
                                  enabled: !isBusy,
                                  wrapSingleLine: true,
                                  onChanged: (val) => cubit.setPersonAge(
                                    personIndex,
                                    int.tryParse(val.trim()) ?? 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Age error shown full width under the row
                          if (ageError != null && ageError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                ageError,
                                style: EverloreTheme.ui(
                                  size: 12,
                                  color: EverloreTheme.crimson,
                                ),
                              ),
                            ),

                          // To you, they are
                          GroupClosenessPicker(
                            label: 'To you, they are',
                            selected: bond ?? GroupCloseness.acquaintance,
                            enabled: !isBusy,
                            onSelected: (val) =>
                                cubit.setPersonStartBond(personIndex, val),
                          ),

                          // Who they are
                          GroupTextField(
                            key: _keyFor('$at.role'),
                            label: 'Who they are',
                            hint: 'e.g. The regular, Barista, Rookie…',
                            initialValue: person.role,
                            errorText: _errorOf(state, '$at.role'),
                            enabled: !isBusy,
                            wrapSingleLine: true,
                            onChanged: (val) =>
                                cubit.setPersonRole(personIndex, val),
                          ),

                          // How they look
                          GroupTextField(
                            key: _keyFor('$at.appearance'),
                            label: 'How they look',
                            hint: 'Tall, lean, dark curls, wireframe glasses…',
                            initialValue: person.appearance,
                            errorText: _errorOf(state, '$at.appearance'),
                            maxLines: null,
                            minLines: 2,
                            useProseFont: true,
                            enabled: !isBusy,
                            onChanged: (val) =>
                                cubit.setPersonAppearance(personIndex, val),
                          ),

                          // Their personality
                          GroupTextField(
                            key: _keyFor('$at.persona'),
                            label: 'Their personality',
                            hint: 'Dry humor, warm underneath, fiercely loyal…',
                            initialValue: person.persona,
                            errorText: _errorOf(state, '$at.persona'),
                            maxLines: null,
                            minLines: 2,
                            useProseFont: true,
                            enabled: !isBusy,
                            onChanged: (val) =>
                                cubit.setPersonPersona(personIndex, val),
                          ),

                          const SizedBox(height: 20),

                          // Fold card containing detailed sections
                          _buildFoldCard(
                            context,
                            cubit,
                            state,
                            person,
                            at,
                            isAdult,
                            isBusy,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pinned gold Done button hidden when keyboard is up
            if (!keyboardUp)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: EverloreTheme.gold,
                      foregroundColor: EverloreTheme.void0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: EverloreTheme.ui(
                        size: 15,
                        weight: FontWeight.w700,
                        color: EverloreTheme.void0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CreateGroupCubit cubit,
    GroupDraftPerson person,
    GroupFace face,
    bool faceWillReset,
    bool isBusy,
    GroupCloseness? bond,
    Color bondTone,
    String bondText,
    double screenHeight,
  ) {
    final headerHeight = min(340.0, screenHeight * 0.42);
    final hasPortrait =
        person.portraitThumbUrl.isNotEmpty || person.portraitUrl.isNotEmpty;
    final isPainting = face.status == GroupFaceStatus.painting;

    final displayName = person.name.trim().isNotEmpty
        ? person.name.trim()
        : 'Person ${personIndex + 1}';

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Visual backdrop: portrait image or arch frame
          if (hasPortrait && !isPainting)
            EverloreNetworkImage(
              imageUrl: person.portraitThumbUrl.isNotEmpty
                  ? person.portraitThumbUrl
                  : person.portraitUrl,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.55),
              placeholder: GroupFaceFrame(
                initial: person.name,
                bond: bond,
                tone: bondTone,
              ),
              errorWidget: GroupFaceFrame(
                initial: person.name,
                bond: bond,
                tone: bondTone,
              ),
            )
          else
            GroupFaceFrame(
              initial: person.name,
              bond: bond,
              tone: bondTone,
              pulsing: isPainting,
            ),

          // Bottom 65% fade gradient to void1
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: headerHeight * 0.65,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    EverloreTheme.void1.withValues(alpha: 0.85),
                    EverloreTheme.void1,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Top right "Paint again" pill when portrait is present
          if (hasPortrait && !isPainting)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: !isBusy
                      ? () => cubit.requestFace(personIndex, repaint: true)
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: EverloreTheme.void0.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Paint again',
                      style: EverloreTheme.ui(
                        size: 12,
                        weight: FontWeight.w600,
                        color: EverloreTheme.gold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Overlay bottom-left: name, age + bond, and face actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.serifDisplay(
                    size: 26,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (person.age > 0) ...[
                      Text(
                        '${person.age}',
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.ash,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: bondTone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      bondText,
                      style: EverloreTheme.ui(
                        size: 12,
                        weight: FontWeight.w500,
                        color: bondTone,
                      ),
                    ),
                  ],
                ),
                if (isPainting) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Painting…',
                    style: EverloreTheme.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: EverloreTheme.gold,
                    ),
                  ),
                ] else if (!hasPortrait) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: !isBusy
                          ? () => cubit.requestFace(personIndex)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: EverloreTheme.gold,
                        foregroundColor: EverloreTheme.void0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Paint a face',
                        style: EverloreTheme.ui(
                          size: 13,
                          weight: FontWeight.w700,
                          color: EverloreTheme.void0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Painted from how they look.',
                    style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                  ),
                ],
                if (face.message != null && face.message!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    face.message!,
                    style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                  ),
                ],
                if (faceWillReset) ...[
                  const SizedBox(height: 6),
                  Text(
                    'This face will be painted again after you save.',
                    style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldCard(
    BuildContext context,
    CreateGroupCubit cubit,
    CreateGroupState state,
    GroupDraftPerson person,
    String at,
    bool isAdult,
    bool isBusy,
  ) {
    // Fold 1: How they talk and what they want
    final talkError =
        _errorOf(state, '$at.group.speech') != null ||
        _errorOf(state, '$at.group.wants') != null ||
        _errorOf(state, '$at.group.talkativeness') != null ||
        (isAdult && _errorOf(state, '$at.group.intimacy') != null);

    // Fold 2: Things they say
    final voiceError =
        _errorOf(state, '$at.group.voice') != null ||
        state.fieldErrors.keys.any((k) => k.startsWith('$at.group.voice')) ||
        state.refusedPaths.any((p) => p.startsWith('$at.group.voice'));

    // Fold 3: First messages to you
    final firstTextsError =
        _errorOf(state, '$at.first_texts') != null ||
        state.fieldErrors.keys.any((k) => k.startsWith('$at.first_texts')) ||
        state.refusedPaths.any((p) => p.startsWith('$at.first_texts'));

    // Fold 4: Their day
    final statusesError =
        state.fieldErrors.keys.any((k) => k.startsWith('$at.statuses')) ||
        state.refusedPaths.any((p) => p.startsWith('$at.statuses'));

    return GroupFoldCard(
      sections: [
        // Fold 1: How they talk and what they want
        GroupFoldSection(
          title: 'How they talk and what they want',
          hasError: talkError,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GroupTextField(
                key: _keyFor('$at.group.speech'),
                label: 'How they talk',
                hint: 'Short, punchy sentences. Often drops pronouns.',
                initialValue: person.speech,
                errorText: _errorOf(state, '$at.group.speech'),
                maxLines: null,
                minLines: 1,
                useProseFont: true,
                enabled: !isBusy,
                onChanged: (val) => cubit.setPersonSpeech(personIndex, val),
              ),
              GroupTextField(
                key: _keyFor('$at.group.wants'),
                label: 'What they want',
                hint: 'To push everyone to beat their best times.',
                initialValue: person.wants,
                errorText: _errorOf(state, '$at.group.wants'),
                maxLines: null,
                minLines: 1,
                useProseFont: true,
                enabled: !isBusy,
                onChanged: (val) => cubit.setPersonWants(personIndex, val),
              ),
              const SizedBox(height: 14),
              Text(
                'How much they talk',
                style: EverloreTheme.ui(
                  size: 12,
                  weight: FontWeight.w500,
                  color: EverloreTheme.ash,
                ),
              ),
              const SizedBox(height: 8),
              _buildTalkativenessSegments(cubit, person.talkativeness, isBusy),
              if (isAdult)
                GroupTextField(
                  key: _keyFor('$at.group.intimacy'),
                  label: 'When it gets intimate',
                  hint: 'Direct, attentive, forgets the competition.',
                  initialValue: person.intimacy,
                  errorText: _errorOf(state, '$at.group.intimacy'),
                  maxLines: null,
                  minLines: 2,
                  useProseFont: true,
                  enabled: !isBusy,
                  onChanged: (val) => cubit.setPersonIntimacy(personIndex, val),
                ),
            ],
          ),
        ),

        // Fold 2: Things they say
        GroupFoldSection(
          title: 'Things they say',
          summary: '${person.voice.length} lines',
          hasError: voiceError,
          child: _buildVoiceSection(cubit, state, person, at, isBusy),
        ),

        // Fold 3: First messages to you
        GroupFoldSection(
          title: 'First messages to you',
          summary: '3 messages',
          hasError: firstTextsError,
          child: _buildFirstTextsSection(cubit, state, person, at, isBusy),
        ),

        // Fold 4: Their day
        GroupFoldSection(
          title: 'Their day',
          summary: 'Morning to Night',
          hasError: statusesError,
          child: _buildStatusesSection(cubit, state, person, at, isBusy),
        ),
      ],
    );
  }

  Widget _buildTalkativenessSegments(
    CreateGroupCubit cubit,
    double currentVal,
    bool isBusy,
  ) {
    // 3 segments: "Mostly listens" (0.25), "Joins in" (0.55), "Talks a lot" (0.85)
    // Nearest shows selected: < 0.4 -> 0; < 0.7 -> 1; else -> 2
    final selectedIndex = currentVal < 0.4 ? 0 : (currentVal < 0.7 ? 1 : 2);

    final segments = [
      ('Mostly listens', 0.25),
      ('Joins in', 0.55),
      ('Talks a lot', 0.85),
    ];

    return Row(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isBusy
                    ? null
                    : () => cubit.setPersonTalkativeness(
                        personIndex,
                        segments[i].$2,
                      ),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  height: 44,
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? EverloreTheme.goldDim.withValues(alpha: 0.14)
                        : EverloreTheme.void3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == selectedIndex
                          ? EverloreTheme.gold
                          : EverloreTheme.white10,
                      width: i == selectedIndex ? 1.4 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      segments[i].$1,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.ui(
                        size: 13,
                        weight: i == selectedIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: i == selectedIndex
                            ? EverloreTheme.gold
                            : EverloreTheme.ash,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceSection(
    CreateGroupCubit cubit,
    CreateGroupState state,
    GroupDraftPerson person,
    String at,
    bool isBusy,
  ) {
    final voiceLines = person.voice;
    final listError = _errorOf(state, '$at.group.voice');
    final orphanedError =
        state.refusedPaths.any(
          (p) =>
              p.startsWith('$at.group.voice.') &&
              (int.tryParse(p.split('.').last) ?? 0) >= voiceLines.length,
        )
        ? "This line can't be saved. Change it."
        : null;
    final displayedVoiceError = listError ?? orphanedError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: _keyFor('$at.group.voice'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sample lines',
              style: EverloreTheme.ui(
                size: 12,
                weight: FontWeight.w500,
                color: EverloreTheme.ash,
              ),
            ),
            if (voiceLines.length < 8)
              TextButton.icon(
                onPressed: isBusy
                    ? null
                    : () => cubit.addVoiceLine(personIndex),
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: EverloreTheme.gold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        if (displayedVoiceError != null) ...[
          const SizedBox(height: 4),
          Text(
            displayedVoiceError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
        ],
        for (var j = 0; j < voiceLines.length; j++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: Text(
                    '${j + 1}.',
                    style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                  ),
                ),
                Expanded(
                  child: GroupTextField(
                    key: _keyFor('$at.group.voice.$j'),
                    hint: 'Line they might say…',
                    initialValue: voiceLines[j],
                    errorText: _errorOf(state, '$at.group.voice.$j'),
                    enabled: !isBusy,
                    useProseFont: true,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setVoiceLine(personIndex, j, val),
                  ),
                ),
                if (voiceLines.length > 1)
                  IconButton(
                    onPressed: isBusy
                        ? null
                        : () => cubit.removeVoiceLine(personIndex, j),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: EverloreTheme.ash,
                    ),
                    padding: const EdgeInsets.only(top: 14),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFirstTextsSection(
    CreateGroupCubit cubit,
    CreateGroupState state,
    GroupDraftPerson person,
    String at,
    bool isBusy,
  ) {
    final listError = _errorOf(state, '$at.first_texts');

    return Column(
      key: _keyFor('$at.first_texts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listError != null) ...[
          Text(
            listError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
          const SizedBox(height: 4),
        ],
        for (var j = 0; j < 3; j++) ...[
          GroupTextField(
            key: _keyFor('$at.first_texts.$j'),
            label: 'Message ${j + 1}',
            hint: 'First text they send…',
            initialValue: j < person.firstTexts.length
                ? person.firstTexts[j]
                : '',
            errorText: _errorOf(state, '$at.first_texts.$j'),
            enabled: !isBusy,
            useProseFont: true,
            wrapSingleLine: true,
            onChanged: (val) => cubit.setFirstText(personIndex, j, val),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusesSection(
    CreateGroupCubit cubit,
    CreateGroupState state,
    GroupDraftPerson person,
    String at,
    bool isBusy,
  ) {
    final periods = [
      ('morning', 'Morning'),
      ('afternoon', 'Afternoon'),
      ('evening', 'Evening'),
      ('night', 'Night'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (period, label) in periods) ...[
          GroupTextField(
            key: _keyFor('$at.statuses.$period'),
            label: label,
            hint: 'What they are doing at $period…',
            initialValue: person.statuses[period] ?? '',
            errorText: _errorOf(state, '$at.statuses.$period'),
            enabled: !isBusy,
            useProseFont: true,
            wrapSingleLine: true,
            onChanged: (val) => cubit.setStatus(personIndex, period, val),
          ),
        ],
      ],
    );
  }
}
