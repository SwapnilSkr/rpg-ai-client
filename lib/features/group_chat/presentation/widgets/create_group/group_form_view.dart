import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_draft.dart';
import 'package:everlore/features/group_chat/state/create_group_cubit.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'group_closeness_picker.dart';
import 'group_text_field.dart';

/// The form view for drafting a new group.
class GroupFormView extends StatelessWidget {
  final CreateGroupState state;

  const GroupFormView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreateGroupCubit>();
    final form = state.form;
    final people = form.people;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          GroupTextField(
            label: 'Title',
            hint: 'Name your group…',
            initialValue: form.title,
            errorText: state.formErrors['title'],
            maxLength: GroupForm.titleMax,
            onChanged: (val) => cubit.updateForm(title: val),
          ),

          // Setting
          GroupTextField(
            label: 'Where are they, and how do they know each other?',
            hint: 'A bouldering gym in Lisbon, old college friends…',
            initialValue: form.setting,
            errorText: state.formErrors['setting'],
            maxLines: 4,
            minLines: 2,
            maxLength: GroupForm.settingMax,
            useProseFont: true,
            onChanged: (val) => cubit.updateForm(setting: val),
          ),

          const SizedBox(height: 16),

          // Adult switch
          _buildAdultSwitch(context, form.adult, (val) {
            cubit.updateForm(adult: val);
          }),

          const SizedBox(height: 24),

          // People header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PEOPLE (${people.length}/${GroupForm.maxPeople})',
                style: EverloreTheme.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  color: EverloreTheme.goldDim,
                  spacing: 1.4,
                ),
              ),
              if (state.formErrors.containsKey('people'))
                Flexible(
                  child: Text(
                    state.formErrors['people']!,
                    style: EverloreTheme.ui(
                      size: 12,
                      color: EverloreTheme.crimson,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Person cards (2–6)
          for (var i = 0; i < people.length; i++) ...[
            _PersonFormCard(
              index: i,
              person: people[i],
              canRemove: people.length > GroupForm.minPeople,
              errors: state.formErrors,
              onChanged: (updated) => cubit.updatePerson(i, updated),
              onRemove: () => cubit.removePerson(i),
            ),
            const SizedBox(height: 14),
          ],

          // Add person button (hidden at 6)
          if (people.length < GroupForm.maxPeople) ...[
            Center(
              child: OutlinedButton.icon(
                onPressed: () => cubit.addPerson(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add a person',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EverloreTheme.gold,
                  disabledForegroundColor: EverloreTheme.ash.withValues(
                    alpha: 0.4,
                  ),
                  side: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 10),

          // "Write my group" button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => cubit.draft(),
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
              child: const Text(
                'Write my group',
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdultSwitch(
    BuildContext context,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EverloreTheme.void2.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
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
                  style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: EverloreTheme.gold,
          ),
        ],
      ),
    );
  }
}

class _PersonFormCard extends StatelessWidget {
  final int index;
  final GroupFormPerson person;
  final bool canRemove;
  final Map<String, String> errors;
  final ValueChanged<GroupFormPerson> onChanged;
  final VoidCallback onRemove;

  const _PersonFormCard({
    required this.index,
    required this.person,
    required this.canRemove,
    required this.errors,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final at = 'people.$index';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Person # and Remove (if allowed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                person.name.trim().isNotEmpty
                    ? person.name.trim()
                    : 'Person ${index + 1}',
                style: EverloreTheme.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: EverloreTheme.parchment,
                ),
              ),
              if (canRemove)
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: EverloreTheme.crimson,
                    disabledForegroundColor: EverloreTheme.ash.withValues(
                      alpha: 0.4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: EverloreTheme.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // Name
          GroupTextField(
            label: 'Name',
            hint: 'Their name…',
            initialValue: person.name,
            errorText: errors['$at.name'],
            maxLength: GroupFormPerson.nameMax,
            onChanged: (val) => onChanged(person.copyWith(name: val)),
          ),

          // Age
          GroupTextField(
            label: 'Age',
            hint: '18+',
            initialValue: person.age?.toString() ?? '',
            errorText: errors['$at.age'],
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final n = int.tryParse(val.trim());
              onChanged(
                n != null
                    ? person.copyWith(age: n)
                    : person.copyWith(clearAge: true),
              );
            },
          ),

          // How they look
          GroupTextField(
            label: 'How they look',
            hint: 'Tall, lean, dark curls, wireframe glasses…',
            initialValue: person.look,
            errorText: errors['$at.look'],
            maxLines: 3,
            minLines: 2,
            maxLength: GroupFormPerson.lookMax,
            useProseFont: true,
            onChanged: (val) => onChanged(person.copyWith(look: val)),
          ),

          // Their personality
          GroupTextField(
            label: 'Their personality',
            hint: 'Dry humor, warm underneath, fiercely loyal…',
            initialValue: person.personality,
            errorText: errors['$at.personality'],
            maxLines: 3,
            minLines: 2,
            maxLength: GroupFormPerson.personalityMax,
            useProseFont: true,
            onChanged: (val) => onChanged(person.copyWith(personality: val)),
          ),

          // How they know you
          GroupTextField(
            label: 'How they know you',
            hint: 'Met through a climbing partner two summers ago…',
            initialValue: person.knowsPlayer,
            errorText: errors['$at.knowsPlayer'],
            maxLines: 2,
            minLines: 1,
            maxLength: GroupFormPerson.knowsPlayerMax,
            useProseFont: true,
            onChanged: (val) => onChanged(person.copyWith(knowsPlayer: val)),
          ),

          // Closeness chips
          GroupClosenessPicker(
            selected: person.closeness,
            onSelected: (val) => onChanged(person.copyWith(closeness: val)),
          ),
        ],
      ),
    );
  }
}
