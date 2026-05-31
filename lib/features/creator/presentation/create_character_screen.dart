import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../state/create_character_cubit.dart';

/// Lightweight, Character.AI-style creation: name a character, describe them,
/// and start chatting immediately. No stats, no RPG scaffolding.
class CreateCharacterScreen extends StatelessWidget {
  const CreateCharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateCharacterCubit(),
      child: const _CreateCharacterView(),
    );
  }
}

class _CreateCharacterView extends StatelessWidget {
  const _CreateCharacterView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateCharacterCubit, CreateCharacterState>(
      listener: (context, state) {
        if (state.instanceId != null) {
          context.go('/play/${state.instanceId}');
        }
      },
      builder: (context, state) {
        final cubit = context.read<CreateCharacterCubit>();
        return Scaffold(
          backgroundColor: EverloreTheme.void1,
          body: SafeArea(
            child: Column(
              children: [
                _Header(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _intro(),
                        const SizedBox(height: 20),
                        _field(
                          label: 'Name',
                          hint: 'e.g. Mira, Captain Vale, Aria…',
                          required: true,
                          onChanged: cubit.setName,
                          textCapitalization: TextCapitalization.words,
                        ),
                        _field(
                          label: 'Tagline',
                          hint: 'A short line — who are they at a glance?',
                          required: true,
                          onChanged: cubit.setTagline,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        _field(
                          label: 'Personality',
                          hint:
                              'How do they think, talk, and treat you? Their mood, quirks, and relationship to you.',
                          required: true,
                          onChanged: cubit.setPersona,
                          maxLines: 6,
                          minLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const _SectionLabel('OPTIONAL'),
                        _field(
                          label: 'Greeting',
                          hint: 'The first thing they say when the chat opens.',
                          onChanged: cubit.setGreeting,
                          maxLines: 3,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        _field(
                          label: 'Backstory & world',
                          hint:
                              'Anything they should always know — their past, setting, relationships.',
                          onChanged: cubit.setBackstory,
                          maxLines: 5,
                          minLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 8),
                        _MatureToggle(
                          value: state.isNsfwCapable,
                          onChanged: cubit.setNsfw,
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorText(state.error!),
                        ],
                      ],
                    ),
                  ),
                ),
                _CreateBar(
                  enabled: state.canCreate && !state.isSubmitting,
                  busy: state.isSubmitting,
                  onCreate: cubit.create,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _intro() => Text(
        'Create someone to talk to. Describe who they are — they\'ll remember '
        'your conversations and grow with them.',
        style: EverloreTheme.ui(
            size: 13, color: EverloreTheme.ash, height: 1.5),
      );

  Widget _field({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    bool required = false,
    int maxLines = 1,
    int minLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w600)),
              if (required)
                Text('  *', style: EverloreTheme.ui(size: 13, color: EverloreTheme.gold)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: onChanged,
            maxLines: maxLines,
            minLines: minLines,
            textCapitalization: textCapitalization,
            style: EverloreTheme.ui(
                size: 14, color: EverloreTheme.parchment, height: 1.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              filled: true,
              fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: EverloreTheme.gold, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: EverloreTheme.ash),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.person_add_alt_1, color: EverloreTheme.violetBright, size: 16),
          const SizedBox(width: 6),
          Text('NEW CHARACTER',
              style: EverloreTheme.ui(
                  size: 12,
                  color: EverloreTheme.violetBright,
                  weight: FontWeight.w800,
                  spacing: 2)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 0),
        child: Text(text,
            style: EverloreTheme.ui(
                size: 11,
                color: EverloreTheme.gold,
                weight: FontWeight.w700,
                spacing: 2)),
      );
}

class _MatureToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MatureToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? EverloreTheme.crimson.withValues(alpha: 0.08)
              : EverloreTheme.void2,
          border: Border.all(
            color: value
                ? EverloreTheme.crimson.withValues(alpha: 0.4)
                : EverloreTheme.goldDim.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined,
                size: 18,
                color: value ? EverloreTheme.crimson : EverloreTheme.ash),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mature character',
                      style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.parchment,
                          weight: FontWeight.w600)),
                  Text('Allows mature themes if you enable them in preferences',
                      style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: EverloreTheme.crimson,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EverloreTheme.crimson.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.35)),
        ),
        child: Text(message,
            style: EverloreTheme.ui(size: 13, color: EverloreTheme.crimson)),
      );
}

class _CreateBar extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onCreate;
  const _CreateBar(
      {required this.enabled, required this.busy, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
          top: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.15)),
        ),
      ),
      child: GestureDetector(
        onTap: enabled ? onCreate : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: enabled
                ? const LinearGradient(
                    colors: [EverloreTheme.violetBright, EverloreTheme.violet])
                : null,
            color: enabled ? null : EverloreTheme.void3,
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: EverloreTheme.parchment),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 18,
                          color: enabled
                              ? EverloreTheme.parchment
                              : EverloreTheme.ash),
                      const SizedBox(width: 10),
                      Text('Create & Chat',
                          style: EverloreTheme.ui(
                              size: 15,
                              color: enabled
                                  ? EverloreTheme.parchment
                                  : EverloreTheme.ash,
                              weight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
