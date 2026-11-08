import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_closeness_picker.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_person_card.dart';
import 'package:everlore/features/group_chat/presentation/widgets/create_group/group_text_field.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';

/// Form view for drafting a new group chat.
///
/// Features a CustomScrollView over the backdrop with a 72 dp spacer,
/// title in aiText 30, setting field, "WHO'S IN IT" grid of cards,
/// bare explicit switch row, pinned "Write my group" button, and
/// the person form bottom sheet.
class GroupFormView extends StatefulWidget {
  final CreateGroupState state;

  const GroupFormView({super.key, required this.state});

  @override
  State<GroupFormView> createState() => _GroupFormViewState();
}

class _GroupFormViewState extends State<GroupFormView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onWriteMyGroup() {
    final cubit = context.read<CreateGroupCubit>();
    // draft() validates synchronously before any network await.
    cubit.draft();
    final errors = cubit.state.formErrors;
    if (errors.isEmpty) return;

    // Scroll to title or setting error when top fields fail.
    if (errors.containsKey('title') || errors.containsKey('setting')) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    // Otherwise reveal the first person with an error in their form sheet.
    final people = cubit.state.form.people;
    for (var i = 0; i < people.length; i++) {
      final hasPersonError = errors.keys.any((k) => k.startsWith('people.$i.'));
      if (hasPersonError) {
        _openPersonSheet(context, i);
        break;
      }
    }
  }

  void _openPersonSheet(BuildContext context, int personIndex) {
    final cubit = context.read<CreateGroupCubit>();
    showEverloreSheet(
      context: context,
      backgroundColor: EverloreTheme.void1,
      builder: (sheetContext) {
        // showEverloreSheet uses the root navigator; pass the cubit value
        // explicitly so errors and edits stay synchronized live.
        return BlocProvider.value(
          value: cubit,
          child: BlocBuilder<CreateGroupCubit, CreateGroupState>(
            builder: (context, state) {
              if (personIndex < 0 || personIndex >= state.form.people.length) {
                return const SizedBox.shrink();
              }
              final person = state.form.people[personIndex];
              final viewInsets = MediaQuery.viewInsetsOf(context);
              final keyboardUp = viewInsets.bottom > 0;
              final screenHeight = MediaQuery.sizeOf(context).height;
              // Never taller than 90% of screen and never taller than height left above keyboard.
              final maxHeight = (screenHeight * 0.9).clamp(
                0.0,
                screenHeight - viewInsets.bottom,
              );

              final canRemove = state.form.people.length > GroupForm.minPeople;
              final topTitle = person.name.trim().isNotEmpty
                  ? person.name.trim()
                  : 'Person ${personIndex + 1}';
              final ageError = state.formErrors['people.$personIndex.age'];

              return Padding(
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SheetGrabHandle(),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topTitle,
                                style: EverloreTheme.ui(
                                  size: 13,
                                  color: EverloreTheme.ash,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: GroupTextField(
                                      label: 'Name',
                                      hint: 'Their name…',
                                      initialValue: person.name,
                                      errorText: state
                                          .formErrors['people.$personIndex.name'],
                                      maxLength: GroupFormPerson.nameMax,
                                      wrapSingleLine: true,
                                      onChanged: (val) => cubit.updatePerson(
                                        personIndex,
                                        person.copyWith(name: val),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: GroupTextField(
                                      label: 'Age',
                                      hint: '18+',
                                      initialValue: person.age != null
                                          ? person.age.toString()
                                          : '',
                                      errorText: ageError,
                                      showErrorText: false,
                                      keyboardType: TextInputType.number,
                                      maxLength: 3,
                                      wrapSingleLine: true,
                                      onChanged: (val) {
                                        final n = int.tryParse(val.trim());
                                        cubit.updatePerson(
                                          personIndex,
                                          n != null
                                              ? person.copyWith(age: n)
                                              : person.copyWith(clearAge: true),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
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
                              GroupClosenessPicker(
                                label: 'To you, they are',
                                selected: person.closeness,
                                onSelected: (val) => cubit.updatePerson(
                                  personIndex,
                                  person.copyWith(closeness: val),
                                ),
                              ),
                              GroupTextField(
                                label: 'How they look',
                                hint:
                                    'Tall, lean, dark curls, wireframe glasses…',
                                initialValue: person.look,
                                errorText: state
                                    .formErrors['people.$personIndex.look'],
                                maxLines: 3,
                                minLines: 2,
                                maxLength: GroupFormPerson.lookMax,
                                useProseFont: true,
                                onChanged: (val) => cubit.updatePerson(
                                  personIndex,
                                  person.copyWith(look: val),
                                ),
                              ),
                              GroupTextField(
                                label: 'Their personality',
                                hint:
                                    'Dry humor, warm underneath, fiercely loyal…',
                                initialValue: person.personality,
                                errorText: state
                                    .formErrors['people.$personIndex.personality'],
                                maxLines: 3,
                                minLines: 2,
                                maxLength: GroupFormPerson.personalityMax,
                                useProseFont: true,
                                onChanged: (val) => cubit.updatePerson(
                                  personIndex,
                                  person.copyWith(personality: val),
                                ),
                              ),
                              GroupTextField(
                                label: 'How they know you',
                                hint:
                                    'Met through a climbing partner two summers ago…',
                                initialValue: person.knowsPlayer,
                                errorText: state
                                    .formErrors['people.$personIndex.knowsPlayer'],
                                maxLines: 2,
                                minLines: 1,
                                maxLength: GroupFormPerson.knowsPlayerMax,
                                useProseFont: true,
                                onChanged: (val) => cubit.updatePerson(
                                  personIndex,
                                  person.copyWith(knowsPlayer: val),
                                ),
                              ),
                              if (canRemove) ...[
                                const SizedBox(height: 24),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      // Close sheet before removal so indices are never shifted while open
                                      Navigator.of(context).pop();
                                      cubit.removePerson(personIndex);
                                    },
                                    child: Text(
                                      'Remove this person',
                                      style: EverloreTheme.ui(
                                        size: 13,
                                        color: EverloreTheme.crimson,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Pinned bottom button hidden when keyboard is visible
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
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final form = widget.state.form;
    final people = form.people;
    final showAddSlot = people.length < GroupForm.maxPeople;
    final gridCount = people.length + (showAddSlot ? 1 : 0);
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 72 dp spacer so the top backdrop art shows through
                    const SizedBox(height: 72),

                    // Title field in aiText 30
                    GroupTextField(
                      hint: 'Name your group',
                      initialValue: form.title,
                      errorText: widget.state.formErrors['title'],
                      maxLength: GroupForm.titleMax,
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
                      onChanged: (val) => cubit.updateForm(title: val),
                    ),

                    // Setting field
                    GroupTextField(
                      label: 'Where do they all know each other from?',
                      hint: 'A bouldering gym in Lisbon, old friends…',
                      initialValue: form.setting,
                      errorText: widget.state.formErrors['setting'],
                      maxLines: 4,
                      minLines: 2,
                      maxLength: GroupForm.settingMax,
                      useProseFont: true,
                      onChanged: (val) => cubit.updateForm(setting: val),
                    ),

                    const SizedBox(height: 28),

                    // Section head: "WHO'S IN IT"
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "WHO'S IN IT",
                          style: EverloreTheme.ui(
                            size: 11,
                            weight: FontWeight.w700,
                            color: EverloreTheme.goldDim,
                            spacing: 1.4,
                          ),
                        ),
                        if (widget.state.formErrors.containsKey('people')) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.state.formErrors['people']!,
                            style: EverloreTheme.ui(
                              size: 12,
                              color: EverloreTheme.crimson,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              // Grid of GroupPersonCards (max 220, aspect ratio 0.76, gap 12)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.76,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < people.length) {
                      return GroupPersonCard.form(
                        person: people[index],
                        index: index,
                        formErrors: widget.state.formErrors,
                        onTap: () => _openPersonSheet(context, index),
                      );
                    }
                    // Add slot card
                    return GroupPersonCard.addSlot(
                      onTap: () {
                        cubit.addPerson();
                        final newIndex = cubit.state.form.people.length - 1;
                        _openPersonSheet(context, newIndex);
                      },
                    );
                  }, childCount: gridCount),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),

                    // Explicit row (bare, no card, same copy, Switch stays)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explicit talk allowed',
                                style: EverloreTheme.ui(
                                  size: 14,
                                  color: EverloreTheme.parchment,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Everyone in the group is an adult.',
                                style: EverloreTheme.ui(
                                  size: 12,
                                  color: EverloreTheme.ash,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: form.adult,
                          onChanged: (val) => cubit.updateForm(adult: val),
                          activeThumbColor: EverloreTheme.goldHot,
                          activeTrackColor: EverloreTheme.gold.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // Pinned "Write my group" button, hidden when keyboard is visible
        if (!keyboardUp)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: EverloreTheme.void0.withValues(alpha: 0.95),
              border: const Border(
                top: BorderSide(color: EverloreTheme.white10, width: 1.0),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _onWriteMyGroup,
                style: FilledButton.styleFrom(
                  backgroundColor: EverloreTheme.gold,
                  foregroundColor: EverloreTheme.void0,
                  disabledBackgroundColor: EverloreTheme.void3,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Write my group',
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
    );
  }
}
