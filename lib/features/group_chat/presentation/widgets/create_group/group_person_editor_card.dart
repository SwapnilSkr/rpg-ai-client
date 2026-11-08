import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/member_avatar.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'group_closeness_picker.dart';
import 'group_text_field.dart';

/// One person in the editor, collapsed by default to face + name + age + closeness.
class GroupPersonEditorCard extends StatelessWidget {
  final int index;
  final GroupDraftPerson person;
  final bool isExpanded;
  final bool isAdult;
  final bool isBusy;
  final GroupFace face;
  final bool faceWillReset;
  final String? Function(String path) errorOf;
  final VoidCallback onToggle;

  const GroupPersonEditorCard({
    super.key,
    required this.index,
    required this.person,
    required this.isExpanded,
    required this.isAdult,
    required this.isBusy,
    required this.face,
    required this.faceWillReset,
    required this.errorOf,
    required this.onToggle,
  });

  static String closenessLabel(String wire) {
    return switch (wire) {
      'acquaintance' => 'Just met',
      'friend' => 'Friend',
      'unrequited_attraction' => 'Has a crush on you',
      'rival' => 'Rival',
      _ => wire.isEmpty ? 'Just met' : wire,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final at = 'seed_cast.$index';

    return Container(
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? EverloreTheme.goldDim.withValues(alpha: 0.35)
              : EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  MemberAvatar(
                    name: person.name,
                    portraitUrl: person.portraitUrl,
                    portraitThumbUrl: person.portraitThumbUrl,
                    size: 42,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name.trim().isNotEmpty
                              ? person.name.trim()
                              : 'Person ${index + 1}',
                          style: EverloreTheme.ui(
                            size: 15,
                            weight: FontWeight.w700,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${person.age > 0 ? '${person.age} · ' : ''}${closenessLabel(person.startBond)}',
                          style: EverloreTheme.ui(
                            size: 12,
                            color: EverloreTheme.ash,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: EverloreTheme.ash,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            const Divider(color: EverloreTheme.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Face section
                  _buildFaceSection(cubit),

                  const SizedBox(height: 16),

                  // Name
                  GroupTextField(
                    label: 'Name',
                    hint: 'Their name…',
                    initialValue: person.name,
                    errorText: errorOf('$at.name'),
                    enabled: !isBusy,
                    maxLength: GroupFormPerson.nameMax,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setPersonName(index, val),
                  ),

                  // Age
                  GroupTextField(
                    label: 'Age',
                    hint: '18+',
                    initialValue: person.age > 0 ? person.age.toString() : '',
                    errorText: errorOf('$at.group.age'),
                    keyboardType: TextInputType.number,
                    enabled: !isBusy,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setPersonAge(
                      index,
                      int.tryParse(val.trim()) ?? 0,
                    ),
                  ),

                  // Closeness picker
                  GroupClosenessPicker(
                    selected:
                        GroupCloseness.fromWire(person.startBond) ??
                        GroupCloseness.acquaintance,
                    enabled: !isBusy,
                    onSelected: (val) => cubit.setPersonStartBond(index, val),
                  ),

                  // Who they are
                  GroupTextField(
                    label: 'Who they are',
                    hint: 'e.g. The regular, Barista, Rookie…',
                    initialValue: person.role,
                    errorText: errorOf('$at.role'),
                    enabled: !isBusy,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setPersonRole(index, val),
                  ),

                  // How they look
                  GroupTextField(
                    label: 'How they look',
                    hint: 'Tall, lean, dark curls, wireframe glasses…',
                    initialValue: person.appearance,
                    errorText: errorOf('$at.appearance'),
                    maxLines: 3,
                    minLines: 2,
                    useProseFont: true,
                    enabled: !isBusy,
                    onChanged: (val) => cubit.setPersonAppearance(index, val),
                  ),

                  // Their personality
                  GroupTextField(
                    label: 'Their personality',
                    hint: 'Dry humor, warm underneath, fiercely loyal…',
                    initialValue: person.persona,
                    errorText: errorOf('$at.persona'),
                    maxLines: 3,
                    minLines: 2,
                    useProseFont: true,
                    enabled: !isBusy,
                    onChanged: (val) => cubit.setPersonPersona(index, val),
                  ),

                  // How they talk
                  GroupTextField(
                    label: 'How they talk',
                    hint: 'Short, punchy sentences. Often drops pronouns.',
                    initialValue: person.speech,
                    errorText: errorOf('$at.group.speech'),
                    maxLines: 2,
                    minLines: 1,
                    useProseFont: true,
                    enabled: !isBusy,
                    onChanged: (val) => cubit.setPersonSpeech(index, val),
                  ),

                  // What they want
                  GroupTextField(
                    label: 'What they want',
                    hint: 'To push everyone to beat their best times.',
                    initialValue: person.wants,
                    errorText: errorOf('$at.group.wants'),
                    maxLines: 2,
                    minLines: 1,
                    useProseFont: true,
                    enabled: !isBusy,
                    onChanged: (val) => cubit.setPersonWants(index, val),
                  ),

                  // How much they talk
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'How much they talk',
                        style: EverloreTheme.ui(
                          size: 13,
                          color: !isBusy
                              ? EverloreTheme.parchment
                              : EverloreTheme.ash,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(person.talkativeness * 100).round()}%',
                        style: EverloreTheme.ui(
                          size: 12,
                          color: EverloreTheme.gold,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: EverloreTheme.gold,
                      inactiveTrackColor: EverloreTheme.void4,
                      thumbColor: EverloreTheme.goldHot,
                      overlayColor: EverloreTheme.gold.withValues(alpha: 0.16),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: person.talkativeness.clamp(0.0, 1.0),
                      onChanged: isBusy
                          ? null
                          : (val) => cubit.setPersonTalkativeness(index, val),
                    ),
                  ),

                  // When it gets intimate (only for adult group)
                  if (isAdult)
                    GroupTextField(
                      label: 'When it gets intimate',
                      hint: 'Direct, attentive, forgets the competition.',
                      initialValue: person.intimacy,
                      errorText: errorOf('$at.group.intimacy'),
                      maxLines: 3,
                      minLines: 2,
                      useProseFont: true,
                      enabled: !isBusy,
                      onChanged: (val) => cubit.setPersonIntimacy(index, val),
                    ),

                  const SizedBox(height: 20),

                  // Things they say (voice)
                  _buildVoiceSection(cubit, at),

                  const SizedBox(height: 20),

                  // First messages to you
                  _buildFirstTextsSection(cubit, at),

                  const SizedBox(height: 20),

                  // Their day
                  _buildStatusesSection(cubit, at),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaceSection(CreateGroupCubit cubit) {
    final hasPortrait = person.portraitUrl.isNotEmpty;
    final status = face.status;

    return Center(
      child: Column(
        children: [
          MemberAvatar(
            name: person.name,
            portraitUrl: person.portraitUrl,
            portraitThumbUrl: person.portraitThumbUrl,
            size: 68,
          ),
          const SizedBox(height: 10),
          if (status == GroupFaceStatus.painting) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: EverloreTheme.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Painting…',
                  style: EverloreTheme.ui(size: 13, color: EverloreTheme.gold),
                ),
              ],
            ),
          ] else if (status == GroupFaceStatus.resting ||
              status == GroupFaceStatus.unseen) ...[
            if (face.message != null && face.message!.isNotEmpty)
              Text(
                face.message!,
                textAlign: TextAlign.center,
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              ),
            const SizedBox(height: 6),
            _faceButton(cubit, hasPortrait),
          ] else ...[
            _faceButton(cubit, hasPortrait),
          ],
          if (faceWillReset) ...[
            const SizedBox(height: 6),
            Text(
              'This face will be painted again after you save.',
              textAlign: TextAlign.center,
              style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
            ),
          ],
        ],
      ),
    );
  }

  Widget _faceButton(CreateGroupCubit cubit, bool hasPortrait) {
    final label = hasPortrait ? 'Paint again' : 'Paint a face';
    return OutlinedButton(
      focusNode: FocusNode(skipTraversal: true),
      onPressed: isBusy
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              cubit.requestFace(index, repaint: hasPortrait);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: EverloreTheme.gold,
        disabledForegroundColor: EverloreTheme.ash.withValues(alpha: 0.4),
        side: BorderSide(
          color: isBusy
              ? EverloreTheme.goldDim.withValues(alpha: 0.15)
              : EverloreTheme.goldDim.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: EverloreTheme.uiFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVoiceSection(CreateGroupCubit cubit, String at) {
    final voiceLines = person.voice;
    final listError = errorOf('$at.group.voice');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Things they say',
              style: EverloreTheme.ui(
                size: 13,
                weight: FontWeight.w700,
                color: EverloreTheme.parchment,
              ),
            ),
            if (voiceLines.length < 8)
              TextButton.icon(
                onPressed: isBusy ? null : () => cubit.addVoiceLine(index),
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
                    hint: 'Line they might say…',
                    initialValue: voiceLines[j],
                    errorText: errorOf('$at.group.voice.$j'),
                    enabled: !isBusy,
                    useProseFont: true,
                    wrapSingleLine: true,
                    onChanged: (val) => cubit.setVoiceLine(index, j, val),
                  ),
                ),
                if (voiceLines.length > 1)
                  IconButton(
                    onPressed: isBusy
                        ? null
                        : () => cubit.removeVoiceLine(index, j),
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

  Widget _buildFirstTextsSection(CreateGroupCubit cubit, String at) {
    final listError = errorOf('$at.first_texts');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'First messages to you',
          style: EverloreTheme.ui(
            size: 13,
            weight: FontWeight.w700,
            color: EverloreTheme.parchment,
          ),
        ),
        if (listError != null) ...[
          const SizedBox(height: 4),
          Text(
            listError,
            style: EverloreTheme.ui(size: 12, color: EverloreTheme.crimson),
          ),
        ],
        for (var j = 0; j < 3; j++) ...[
          GroupTextField(
            hint: 'Message ${j + 1}',
            initialValue: j < person.firstTexts.length
                ? person.firstTexts[j]
                : '',
            errorText: errorOf('$at.first_texts.$j'),
            enabled: !isBusy,
            useProseFont: true,
            wrapSingleLine: true,
            onChanged: (val) => cubit.setFirstText(index, j, val),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusesSection(CreateGroupCubit cubit, String at) {
    final periods = [
      ('morning', 'Morning'),
      ('afternoon', 'Afternoon'),
      ('evening', 'Evening'),
      ('night', 'Night'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Their day',
          style: EverloreTheme.ui(
            size: 13,
            weight: FontWeight.w700,
            color: EverloreTheme.parchment,
          ),
        ),
        for (final (period, label) in periods) ...[
          GroupTextField(
            label: label,
            hint: 'What they are doing at $period…',
            initialValue: person.statuses[period] ?? '',
            errorText: errorOf('$at.statuses.$period'),
            enabled: !isBusy,
            useProseFont: true,
            wrapSingleLine: true,
            onChanged: (val) => cubit.setStatus(index, period, val),
          ),
        ],
      ],
    );
  }
}
