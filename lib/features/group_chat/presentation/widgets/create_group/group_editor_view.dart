import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_fold_section.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_card.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_editor_sheet.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_text_field.dart';
import 'package:everlore/features/group_chat/presentation/widgets/member_avatar.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';

/// The group editor view: title, description, cast grid of GroupPersonCard,
/// the four story folds, and bottom bar.
class GroupEditorView extends StatefulWidget {
  final CreateGroupState state;

  const GroupEditorView({super.key, required this.state});

  @visibleForTesting
  static void resetSavedState() {
    _GroupEditorViewState._savedOffsets.clear();
  }

  @override
  State<GroupEditorView> createState() => _GroupEditorViewState();
}

class _GroupEditorViewState extends State<GroupEditorView> {
  static final Map<String, double> _savedOffsets = {};

  late final ScrollController _scrollController;
  final GlobalKey _storyKey = GlobalKey();
  int? _openPersonIndex;

  String get _storageKey => widget.state.draft?.id ?? 'draft';

  @override
  void initState() {
    super.initState();
    final initialOffset = _savedOffsets[_storageKey] ?? 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _savedOffsets[_storageKey] = _scrollController.offset;
      }
    });
  }

  @override
  void didUpdateWidget(covariant GroupEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.draft?.id == null && widget.state.draft?.id != null) {
      if (_savedOffsets.containsKey('draft')) {
        _savedOffsets[widget.state.draft!.id!] = _savedOffsets['draft']!;
      }
    }

    // Trigger reveal only when a path appears that was not in the old fieldErrors or old refusedPaths
    final hasNewError =
        widget.state.fieldErrors.keys.any(
          (p) => !oldWidget.state.fieldErrors.containsKey(p),
        ) ||
        widget.state.refusedPaths.any(
          (p) => !oldWidget.state.refusedPaths.contains(p),
        );

    if (hasNewError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleErrorsAndScroll();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleErrorsAndScroll() {
    final state = widget.state;
    final allPaths = {...state.fieldErrors.keys, ...state.refusedPaths};
    if (allPaths.isEmpty) return;

    // 1. Check for person refusal or error: seed_cast.N...
    final cast = state.draft?.cast ?? [];
    for (var i = 0; i < cast.length; i++) {
      final prefix = 'seed_cast.$i';
      final hasCastError = allPaths.any(
        (p) => p == prefix || p.startsWith('$prefix.'),
      );
      if (hasCastError) {
        _openPersonEditorSheet(context, i, scrollToFirstError: true);
        return;
      }
    }

    // 2. Title or description errors scroll to top
    if (allPaths.contains('title') || allPaths.contains('description')) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    // 3. Story errors: seed_prompt, global_lore, topics, opening_lines
    if (allPaths.any(
      (p) =>
          p == 'seed_prompt' ||
          p == 'global_lore' ||
          p.startsWith('topics') ||
          p.startsWith('opening_lines'),
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _storyKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _openPersonEditorSheet(
    BuildContext context,
    int index, {
    bool scrollToFirstError = false,
  }) {
    if (_openPersonIndex == index) return;
    if (_openPersonIndex != null) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _openPersonIndex = index;
    showGroupPersonEditorSheet(
      context,
      personIndex: index,
      scrollToFirstError: scrollToFirstError,
    ).then((_) {
      if (_openPersonIndex == index) {
        _openPersonIndex = null;
      }
    });
  }

  String? _errorOf(String path) {
    if (widget.state.fieldErrors.containsKey(path)) {
      return widget.state.fieldErrors[path];
    }
    if (widget.state.refusedPaths.contains(path)) {
      return "This line can't be saved. Change it.";
    }
    return null;
  }

  bool _canPaintEveryone(CreateGroupState state) {
    final draft = state.draft;
    if (draft == null || state.isBusy) return false;
    final anyPainting = state.faces.values.any(
      (f) => f.status == GroupFaceStatus.painting,
    );
    if (anyPainting) return false;

    return draft.cast.any((p) {
      final hasFace = p.portraitThumbUrl.isNotEmpty || p.portraitUrl.isNotEmpty;
      return !hasFace;
    });
  }

  Future<void> _paintEveryone() async {
    final cubit = context.read<CreateGroupCubit>();
    if (cubit.state.needsSave) {
      final ok = await cubit.save();
      if (!ok) {
        if (mounted) _handleErrorsAndScroll();
        return;
      }
    }
    if (!mounted) return;
    final cast = cubit.state.draft?.cast ?? [];
    for (var i = 0; i < cast.length; i++) {
      if (!mounted) return;
      final person = cubit.state.draft?.cast[i];
      if (person == null) continue;
      final hasFace =
          person.portraitThumbUrl.isNotEmpty || person.portraitUrl.isNotEmpty;
      final faceState = cubit.state.faceOf(i);
      if (!hasFace && faceState.status == GroupFaceStatus.idle) {
        await cubit.requestFace(i);
      }
    }
  }

  Future<void> _paintFaceForPerson(int index) async {
    final cubit = context.read<CreateGroupCubit>();
    if (cubit.state.needsSave) {
      final ok = await cubit.save();
      if (!ok) {
        _handleErrorsAndScroll();
        return;
      }
    }
    await cubit.requestFace(index);
  }

  Future<void> _openPublishSheet(BuildContext context) async {
    final draft = widget.state.draft;
    if (draft == null) return;
    final cubit = context.read<CreateGroupCubit>();
    final allowPublic = widget.state.everyoneHasFace;

    final cast = draft.cast;
    final missingCount = [
      for (var i = 0; i < cast.length; i++) i,
    ].where((i) => !widget.state.hasFace(i)).length;
    final disabledReason = allowPublic
        ? null
        : (missingCount == 1
              ? '1 person still needs a face.'
              : '$missingCount people still need a face.');

    var refused = false;
    await PublishWorldSheet.show(
      context,
      WorldTemplate(
        id: draft.id ?? '',
        creatorId: '',
        title: draft.title,
        slug: '',
        description: draft.description,
        kind: 'group',
        isPublished: draft.isPublished,
        visibility: draft.visibility,
        reviewStatus: draft.reviewStatus,
        imageThumbUrl: draft.imageThumbUrl,
      ),
      initialVisibility: draft.visibility.isNotEmpty
          ? draft.visibility
          : 'private',
      choiceButtonLabels: true,
      onPublish: (t) async {
        final ok = await cubit.publish(t);
        // A refused line can't be fixed from this sheet: close it and show the line.
        refused =
            !ok &&
            (cubit.state.refusedPaths.isNotEmpty ||
                cubit.state.fieldErrors.isNotEmpty);
        return ok || refused;
      },
      noun: 'group',
      allowPublic: allowPublic,
      publicDisabledReason: disabledReason,
    );

    if (refused && context.mounted) _handleErrorsAndScroll();
  }

  String _firstTwoLines(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(2)
        .toList();
    if (lines.isEmpty) return '';
    return lines.join(' ');
  }

  void _openSpeakerPicker(BuildContext context, int lineIndex) {
    final draft = widget.state.draft;
    if (draft == null) return;
    showEverloreSheet(
      context: context,
      backgroundColor: EverloreTheme.void1,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetGrabHandle(),
                const SizedBox(height: 16),
                Text(
                  'Who is speaking?',
                  style: EverloreTheme.serifDisplay(
                    size: 18,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final person in draft.cast)
                      InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.read<CreateGroupCubit>().setOpeningSpeaker(
                            lineIndex,
                            person.name,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MemberAvatar(
                                name: person.name,
                                portraitUrl: person.portraitUrl,
                                portraitThumbUrl: person.portraitThumbUrl,
                                size: 44,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                person.name.isNotEmpty
                                    ? person.name
                                    : 'Someone',
                                style: EverloreTheme.ui(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: EverloreTheme.parchment,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.state.draft;
    if (draft == null) return const SizedBox.shrink();

    final cubit = context.read<CreateGroupCubit>();
    final isBusy = widget.state.isBusy;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final keyboardUp = viewInsets.bottom > 0;

    final noOneHasFace = draft.cast.every(
      (p) => (p.portraitUrl.isEmpty && p.portraitThumbUrl.isEmpty),
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('group_editor_scroll_view'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 72 dp spacer so backdrop art shows
                const SizedBox(height: 72),

                // 2. Title field: aiText 30
                GroupTextField(
                  hint: 'Group title…',
                  initialValue: draft.title,
                  errorText: _errorOf('title'),
                  enabled: !isBusy,
                  wrapSingleLine: true,
                  style: EverloreTheme.aiText.copyWith(
                    fontSize: 30,
                    height: 1.2,
                    color: EverloreTheme.parchment,
                  ),
                  hintStyle: EverloreTheme.aiText.copyWith(
                    fontSize: 30,
                    height: 1.2,
                    color: EverloreTheme.ash.withValues(alpha: 0.75),
                  ),
                  onChanged: cubit.setTitle,
                ),

                // 3. Description field at 16, no label, full text
                GroupTextField(
                  hint: 'About this group…',
                  initialValue: draft.description,
                  errorText: _errorOf('description'),
                  enabled: !isBusy,
                  useProseFont: true,
                  maxLines: null,
                  minLines: 1,
                  onChanged: cubit.setDescription,
                ),

                const SizedBox(height: 28),

                // 4. "WHO'S IN IT" section (fixed 44 dp height so cards never jump when link disappears)
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "WHO'S IN IT",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 11,
                            weight: FontWeight.w700,
                            color: EverloreTheme.goldDim,
                            spacing: 1.4,
                          ),
                        ),
                      ),
                      if (_canPaintEveryone(widget.state)) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: !isBusy ? _paintEveryone : null,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Paint everyone',
                              maxLines: 1,
                              style: EverloreTheme.ui(
                                size: 13,
                                weight: FontWeight.w600,
                                color: EverloreTheme.gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_errorOf('seed_cast') != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorOf('seed_cast')!,
                    style: EverloreTheme.ui(
                      size: 12,
                      color: EverloreTheme.crimson,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Grid of GroupPersonCard
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.76,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: draft.cast.length,
                  itemBuilder: (context, i) {
                    final person = draft.cast[i];
                    final at = 'seed_cast.$i';
                    final hasPersonError =
                        widget.state.fieldErrors.keys.any(
                          (k) => k == at || k.startsWith('$at.'),
                        ) ||
                        widget.state.refusedPaths.any(
                          (p) => p == at || p.startsWith('$at.'),
                        );

                    return GroupPersonCard.editor(
                      key: ValueKey('editor_card_$i'),
                      person: person,
                      index: i,
                      face: widget.state.faceOf(i),
                      faceWillReset: widget.state.faceWillReset(i),
                      hasError: hasPersonError,
                      errorMessage: hasPersonError ? 'Needs a look' : null,
                      onTap: () => _openPersonEditorSheet(context, i),
                      onPaintFace: () => _paintFaceForPerson(i),
                    );
                  },
                ),

                if (noOneHasFace)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap anyone to read or change them.',
                      style: EverloreTheme.aiText.copyWith(
                        fontSize: 14,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // 5. "THE STORY" head and fold card
                Text(
                  'THE STORY',
                  style: EverloreTheme.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: EverloreTheme.goldDim,
                    spacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  key: _storyKey,
                  child: GroupFoldCard(
                    sections: [
                      // Fold 1: How it begins (seedPrompt)
                      GroupFoldSection(
                        title: 'How it begins',
                        summary: _firstTwoLines(draft.seedPrompt),
                        hasError: _errorOf('seed_prompt') != null,
                        child: GroupTextField(
                          hint: 'Direction for how the group behaves…',
                          initialValue: draft.seedPrompt,
                          errorText: _errorOf('seed_prompt'),
                          maxLines: null,
                          minLines: 2,
                          useProseFont: true,
                          enabled: !isBusy,
                          onChanged: cubit.setSeedPrompt,
                        ),
                      ),

                      // Fold 2: The setting (globalLore)
                      GroupFoldSection(
                        title: 'The setting',
                        summary: _firstTwoLines(draft.globalLore),
                        hasError: _errorOf('global_lore') != null,
                        child: GroupTextField(
                          hint: 'Where this group is and background lore…',
                          initialValue: draft.globalLore,
                          errorText: _errorOf('global_lore'),
                          maxLines: null,
                          minLines: 2,
                          useProseFont: true,
                          enabled: !isBusy,
                          onChanged: cubit.setGlobalLore,
                        ),
                      ),

                      // Fold 3: What they talk about (topics)
                      GroupFoldSection(
                        title: 'What they talk about',
                        summary: '${draft.topics.length} topics',
                        hasError:
                            _errorOf('topics') != null ||
                            draft.topics.asMap().keys.any(
                              (j) => _errorOf('topics.$j') != null,
                            ),
                        child: _buildTopicsFold(cubit, draft, isBusy),
                      ),

                      // Fold 4: The first conversation (openingLines)
                      GroupFoldSection(
                        title: 'The first conversation',
                        summary: '${draft.openingLines.length} lines',
                        hasError:
                            _errorOf('opening_lines') != null ||
                            draft.openingLines.asMap().keys.any(
                              (j) =>
                                  _errorOf('opening_lines.$j.name') != null ||
                                  _errorOf('opening_lines.$j.text') != null,
                            ),
                        child: _buildOpeningConversationFold(
                          context,
                          cubit,
                          draft,
                          isBusy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom bar: hidden when keyboard is up
        if (!keyboardUp) _buildBottomBar(context, draft, cubit),
      ],
    );
  }

  Widget _buildTopicsFold(
    CreateGroupCubit cubit,
    GroupDraft draft,
    bool isBusy,
  ) {
    final listError = _errorOf('topics');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listError != null) ...[
          Text(
            listError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
          const SizedBox(height: 4),
        ],
        for (var j = 0; j < draft.topics.length; j++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GroupTextField(
                    hint: 'A topic they talk about…',
                    initialValue: draft.topics[j],
                    errorText: _errorOf('topics.$j'),
                    enabled: !isBusy,
                    useProseFont: true,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setTopic(j, val),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    onPressed: isBusy ? null : () => cubit.removeTopic(j),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: EverloreTheme.ash,
                    ),
                    padding: const EdgeInsets.only(top: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isBusy ? null : cubit.addTopic,
          icon: const Icon(Icons.add, size: 14),
          label: const Text(
            'Add a topic',
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: EverloreTheme.gold,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildOpeningConversationFold(
    BuildContext context,
    CreateGroupCubit cubit,
    GroupDraft draft,
    bool isBusy,
  ) {
    final listError = _errorOf('opening_lines');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listError != null) ...[
          Text(
            listError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
          const SizedBox(height: 4),
        ],
        for (var j = 0; j < draft.openingLines.length; j++) ...[
          _buildOpeningLineBubble(context, cubit, draft, j, isBusy),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: isBusy ? null : cubit.addOpeningLine,
          icon: const Icon(Icons.add, size: 14),
          label: const Text(
            'Add a line',
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: EverloreTheme.gold,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildOpeningLineBubble(
    BuildContext context,
    CreateGroupCubit cubit,
    GroupDraft draft,
    int lineIndex,
    bool isBusy,
  ) {
    final line = draft.openingLines[lineIndex];
    final speakerPerson = draft.cast.cast<GroupDraftPerson?>().firstWhere(
      (p) => p?.name == line.name,
      orElse: () => null,
    );
    final speakerError = _errorOf('opening_lines.$lineIndex.name');
    final textError = _errorOf('opening_lines.$lineIndex.text');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(
                name: line.name,
                portraitUrl: speakerPerson?.portraitUrl,
                portraitThumbUrl: speakerPerson?.portraitThumbUrl,
                size: 28,
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: isBusy
                    ? null
                    : () => _openSpeakerPicker(context, lineIndex),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line.name.isNotEmpty ? line.name : 'Select speaker',
                        style: EverloreTheme.ui(
                          size: 12,
                          weight: FontWeight.w700,
                          color: EverloreTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: EverloreTheme.gold,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: isBusy
                      ? null
                      : () => cubit.removeOpeningLine(lineIndex),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: EverloreTheme.ash,
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: EverloreTheme.void3,
              borderRadius: BorderRadius.circular(14),
            ),
            child: GroupTextField(
              hint: 'Opening line…',
              initialValue: line.text,
              errorText: textError,
              enabled: !isBusy,
              useProseFont: true,
              wrapSingleLine: true,
              underlineOnlyOnFocusOrError: true,
              onChanged: (val) => cubit.setOpeningText(lineIndex, val),
            ),
          ),
          if (speakerError != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 4),
              child: Text(
                speakerError,
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    GroupDraft draft,
    CreateGroupCubit cubit,
  ) {
    final isBusy = widget.state.isBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.16)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Share button (outlined, 104 x 48)
            OutlinedButton(
              onPressed: !isBusy ? () => _openPublishSheet(context) : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                ),
                foregroundColor: EverloreTheme.parchment,
                minimumSize: const Size(104, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Share',
                    style: EverloreTheme.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Primary: Start chatting (gold, Expanded, 48)
            Expanded(
              child: FilledButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        if (widget.state.needsSave) {
                          final ok = await cubit.save();
                          if (!ok) {
                            _handleErrorsAndScroll();
                            return;
                          }
                        }
                        final id = cubit.state.draft?.id;
                        if (id != null && context.mounted) {
                          context.push('/group-preview/$id');
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  disabledBackgroundColor: EverloreTheme.void3,
                  foregroundColor: EverloreTheme.void0,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.4,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Start chatting',
                  style: EverloreTheme.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: isBusy
                        ? EverloreTheme.ash.withValues(alpha: 0.4)
                        : EverloreTheme.void0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
