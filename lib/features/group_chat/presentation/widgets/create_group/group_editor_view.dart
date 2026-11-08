import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/creator/presentation/widgets/publish_world_sheet.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/models/world_template.dart';
import 'group_person_editor_card.dart';
import 'group_text_field.dart';

/// The editing screen: one scrolling page for every field of a group.
class GroupEditorView extends StatefulWidget {
  final CreateGroupState state;

  const GroupEditorView({super.key, required this.state});

  @visibleForTesting
  static void resetSavedState() {
    _GroupEditorViewState._savedExpanded.clear();
    _GroupEditorViewState._savedOffsets.clear();
  }

  @override
  State<GroupEditorView> createState() => _GroupEditorViewState();
}

class _GroupEditorViewState extends State<GroupEditorView> {
  static final Map<String, Set<int>> _savedExpanded = {};
  static final Map<String, double> _savedOffsets = {};

  late final ScrollController _scrollController;
  final Set<int> _expandedPeople = {};

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _topicsKey = GlobalKey();
  final GlobalKey _openingLinesKey = GlobalKey();
  final Map<int, GlobalKey> _personKeys = {};

  String get _storageKey => widget.state.draft?.id ?? 'draft';

  @override
  void initState() {
    super.initState();
    final saved = _savedExpanded[_storageKey];
    if (saved != null) {
      _expandedPeople.addAll(saved);
    }
    final initialOffset = _savedOffsets[_storageKey] ?? 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _savedOffsets[_storageKey] = _scrollController.offset;
      }
    });
  }

  void _togglePerson(int index) {
    setState(() {
      if (_expandedPeople.contains(index)) {
        _expandedPeople.remove(index);
      } else {
        _expandedPeople.add(index);
      }
      _savedExpanded[_storageKey] = Set.from(_expandedPeople);
    });
  }

  @override
  void didUpdateWidget(covariant GroupEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If draft.id changed from null to an id, transfer saved expanded state
    if (oldWidget.state.draft?.id == null && widget.state.draft?.id != null) {
      _savedExpanded[widget.state.draft!.id!] = Set.from(_expandedPeople);
      if (_savedOffsets.containsKey('draft')) {
        _savedOffsets[widget.state.draft!.id!] = _savedOffsets['draft']!;
      }
    }
    // When a save fails with field errors, scroll to and expand the first person or section
    if (widget.state.fieldErrors.isNotEmpty &&
        !mapEquals(widget.state.fieldErrors, oldWidget.state.fieldErrors)) {
      _handleErrorsAndScroll();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleErrorsAndScroll() {
    final errors = widget.state.fieldErrors;
    // Look for first person error
    for (var i = 0; i < (widget.state.draft?.cast.length ?? 0); i++) {
      final prefix = 'seed_cast.$i';
      final hasPersonError = errors.keys.any(
        (k) => k == prefix || k.startsWith('$prefix.'),
      );
      if (hasPersonError) {
        setState(() {
          _expandedPeople.add(i);
          _savedExpanded[_storageKey] = Set.from(_expandedPeople);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _personKeys[i]?.currentContext;
          if (target != null) {
            Scrollable.ensureVisible(
              target,
              alignment: 0.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOut,
            );
          }
        });
        return;
      }
    }

    // Otherwise check top sections
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (errors.containsKey('title')) {
        final ctx = _titleKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 320),
          );
        }
      } else if (errors.keys.any((k) => k.startsWith('topics'))) {
        final ctx = _topicsKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 320),
          );
        }
      } else if (errors.keys.any((k) => k.startsWith('opening_lines'))) {
        final ctx = _openingLinesKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.0,
            duration: const Duration(milliseconds: 320),
          );
        }
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

  void _openPublishSheet(BuildContext context) {
    final draft = widget.state.draft;
    if (draft == null) return;
    final cubit = context.read<CreateGroupCubit>();
    final allowPublic = widget.state.everyoneHasFace;

    PublishWorldSheet.show(
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
      onPublish: cubit.publish,
      noun: 'group',
      allowPublic: allowPublic,
      publicDisabledReason: allowPublic
          ? null
          : 'Every person needs a face first.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.state.draft;
    if (draft == null) return const SizedBox.shrink();

    final cubit = context.read<CreateGroupCubit>();
    final isBusy = widget.state.isBusy;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('group_editor_scroll_view'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Title
                Container(
                  key: _titleKey,
                  child: GroupTextField(
                    label: 'Title',
                    hint: 'Group title…',
                    initialValue: draft.title,
                    errorText: _errorOf('title'),
                    enabled: !isBusy,
                    wrapSingleLine: true,
                    onChanged: cubit.setTitle,
                  ),
                ),

                // 2. About this group
                GroupTextField(
                  label: 'About this group',
                  hint: 'Short description…',
                  initialValue: draft.description,
                  errorText: _errorOf('description'),
                  maxLines: 3,
                  minLines: 2,
                  useProseFont: true,
                  enabled: !isBusy,
                  onChanged: cubit.setDescription,
                ),

                // 3. The setting
                GroupTextField(
                  label: 'The setting',
                  hint: 'Where this group is and background lore…',
                  initialValue: draft.globalLore,
                  errorText: _errorOf('global_lore'),
                  maxLines: 4,
                  minLines: 2,
                  useProseFont: true,
                  enabled: !isBusy,
                  onChanged: cubit.setGlobalLore,
                ),

                // 4. How the chat goes
                GroupTextField(
                  label: 'How the chat goes',
                  hint: 'Direction for how the group behaves…',
                  initialValue: draft.seedPrompt,
                  errorText: _errorOf('seed_prompt'),
                  maxLines: 4,
                  minLines: 2,
                  useProseFont: true,
                  enabled: !isBusy,
                  onChanged: cubit.setSeedPrompt,
                ),

                const SizedBox(height: 24),

                // 5. Topics
                _buildTopicsSection(draft, cubit, isBusy),

                const SizedBox(height: 24),

                // 6. Opening conversation
                _buildOpeningConversationSection(draft, cubit, isBusy),

                const SizedBox(height: 24),

                // 7. Person cards
                _buildCastSection(draft, cubit, isBusy),
              ],
            ),
          ),
        ),

        // Bottom bar
        _buildBottomBar(context, draft, cubit),
      ],
    );
  }

  Widget _buildTopicsSection(
    GroupDraft draft,
    CreateGroupCubit cubit,
    bool isBusy,
  ) {
    final listError = _errorOf('topics');

    return Container(
      key: _topicsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Topics',
                style: EverloreTheme.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: EverloreTheme.parchment,
                ),
              ),
              TextButton.icon(
                onPressed: isBusy ? null : cubit.addTopic,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add topic',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: EverloreTheme.gold,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.4,
                  ),
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
          if (listError != null) ...[
            const SizedBox(height: 4),
            Text(
              listError,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
            ),
          ],
          for (var i = 0; i < draft.topics.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GroupTextField(
                      hint: 'A topic they talk about…',
                      initialValue: draft.topics[i],
                      errorText: _errorOf('topics.$i'),
                      enabled: !isBusy,
                      useProseFont: true,
                      wrapSingleLine: true,
                      onChanged: (val) => cubit.setTopic(i, val),
                    ),
                  ),
                  IconButton(
                    onPressed: isBusy ? null : () => cubit.removeTopic(i),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: EverloreTheme.ash,
                    ),
                    padding: const EdgeInsets.only(top: 20),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOpeningConversationSection(
    GroupDraft draft,
    CreateGroupCubit cubit,
    bool isBusy,
  ) {
    final listError = _errorOf('opening_lines');
    final castNames = draft.cast
        .map((p) => p.name.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return Container(
      key: _openingLinesKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opening conversation',
                style: EverloreTheme.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: EverloreTheme.parchment,
                ),
              ),
              TextButton.icon(
                onPressed: isBusy ? null : cubit.addOpeningLine,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add line',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: EverloreTheme.gold,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.4,
                  ),
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
          if (listError != null) ...[
            const SizedBox(height: 4),
            Text(
              listError,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
            ),
          ],
          for (var i = 0; i < draft.openingLines.length; i++) ...[
            _OpeningLineEditor(
              index: i,
              line: draft.openingLines[i],
              availableNames: castNames,
              isBusy: isBusy,
              speakerError: _errorOf('opening_lines.$i.name'),
              textError: _errorOf('opening_lines.$i.text'),
              onSpeakerChanged: (name) => cubit.setOpeningSpeaker(i, name),
              onTextChanged: (text) => cubit.setOpeningText(i, text),
              onRemove: () => cubit.removeOpeningLine(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCastSection(
    GroupDraft draft,
    CreateGroupCubit cubit,
    bool isBusy,
  ) {
    final listError = _errorOf('seed_cast');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PEOPLE (${draft.cast.length})',
          style: EverloreTheme.ui(
            size: 11,
            weight: FontWeight.w700,
            color: EverloreTheme.goldDim,
            spacing: 1.4,
          ),
        ),
        if (listError != null) ...[
          const SizedBox(height: 4),
          Text(
            listError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < draft.cast.length; i++) ...[
          Container(
            key: _personKeys.putIfAbsent(i, () => GlobalKey()),
            child: GroupPersonEditorCard(
              index: i,
              person: draft.cast[i],
              isExpanded: _expandedPeople.contains(i),
              isAdult: draft.isNsfwCapable,
              isBusy: isBusy,
              face: widget.state.faceOf(i),
              faceWillReset: widget.state.faceWillReset(i),
              errorOf: _errorOf,
              onToggle: () => _togglePerson(i),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    GroupDraft draft,
    CreateGroupCubit cubit,
  ) {
    final isBusy = widget.state.isBusy;
    final isSaving = widget.state.isSaving;
    final needsSave = widget.state.needsSave;
    final canSave = needsSave && !isBusy;
    final canChat = draft.id != null && !widget.state.isDirty && !isBusy;

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
            // Save button
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: canSave ? () => cubit.save() : null,
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  disabledBackgroundColor: EverloreTheme.void3,
                  foregroundColor: EverloreTheme.void0,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: EverloreTheme.void0,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: EverloreTheme.uiFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // Share button
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: !isBusy ? () => _openPublishSheet(context) : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                  ),
                  foregroundColor: EverloreTheme.parchment,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Share',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Chat button
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: canChat
                    ? () => context.push('/group-preview/${draft.id}')
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.void3,
                  disabledBackgroundColor: EverloreTheme.void4.withValues(
                    alpha: 0.4,
                  ),
                  foregroundColor: EverloreTheme.parchment,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.4,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Chat',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _OpeningLineEditor extends StatelessWidget {
  final int index;
  final GroupOpeningLine line;
  final List<String> availableNames;
  final bool isBusy;
  final String? speakerError;
  final String? textError;
  final ValueChanged<String> onSpeakerChanged;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onRemove;

  const _OpeningLineEditor({
    required this.index,
    required this.line,
    required this.availableNames,
    required this.isBusy,
    this.speakerError,
    this.textError,
    required this.onSpeakerChanged,
    required this.onTextChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure current line speaker is among items
    final names = [...availableNames];
    if (line.name.isNotEmpty && !names.contains(line.name)) {
      names.add(line.name);
    }
    final selectedName = names.contains(line.name)
        ? line.name
        : (names.isNotEmpty ? names.first : '');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker dropdown
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: EverloreTheme.void4.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: speakerError != null
                        ? EverloreTheme.crimson
                        : EverloreTheme.goldDim.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedName.isNotEmpty ? selectedName : null,
                    hint: Text(
                      'Speaker',
                      style: EverloreTheme.ui(
                        size: 13,
                        color: EverloreTheme.ash,
                      ),
                    ),
                    dropdownColor: EverloreTheme.void2,
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w600,
                    ),
                    items: [
                      for (final name in names)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: isBusy
                        ? null
                        : (val) {
                            if (val != null) onSpeakerChanged(val);
                          },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: GroupTextField(
                  hint: 'Opening line…',
                  initialValue: line.text,
                  errorText: textError,
                  enabled: !isBusy,
                  useProseFont: true,
                  wrapSingleLine: true,
                  onChanged: onTextChanged,
                ),
              ),

              // Remove
              IconButton(
                onPressed: isBusy ? null : onRemove,
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: EverloreTheme.ash,
                ),
                padding: const EdgeInsets.only(top: 20),
              ),
            ],
          ),
          if (speakerError != null) ...[
            const SizedBox(height: 4),
            Text(
              speakerError!,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
            ),
          ],
        ],
      ),
    );
  }
}
