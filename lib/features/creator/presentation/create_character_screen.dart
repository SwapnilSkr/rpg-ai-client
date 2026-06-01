import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/nexus_theme.dart';
import '../state/create_character_cubit.dart';
import 'widgets/voice_picker.dart';
import 'widgets/image_forge.dart';
import 'widgets/autofill_card.dart';

/// Character.AI-style creation, broken into three light steps so no single
/// screen overloads the creator: who they are → voice & story → portrait.
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

const _charStepNames = ['WHO THEY ARE', 'VOICE & STORY', 'PORTRAIT'];
final _charStepCount = _charStepNames.length;

class _CreateCharacterView extends StatefulWidget {
  const _CreateCharacterView();

  @override
  State<_CreateCharacterView> createState() => _CreateCharacterViewState();
}

class _CreateCharacterViewState extends State<_CreateCharacterView> {
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _personaCtrl = TextEditingController();
  final _greetingCtrl = TextEditingController();
  final _backstoryCtrl = TextEditingController();
  int _step = 0;
  int _lastAutofillStamp = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _personaCtrl.dispose();
    _greetingCtrl.dispose();
    _backstoryCtrl.dispose();
    super.dispose();
  }

  // Push AI-drafted field values back into the controllers so the form shows them.
  // Controllers live at the screen level, so values persist across step changes.
  void _syncFromState(CreateCharacterState s) {
    _nameCtrl.text = s.name;
    _taglineCtrl.text = s.tagline;
    _personaCtrl.text = s.persona;
    _greetingCtrl.text = s.greeting;
    _backstoryCtrl.text = s.backstory;
  }

  void _next() {
    if (_step < _charStepCount - 1) setState(() => _step += 1);
  }

  void _back() {
    if (_step > 0) setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateCharacterCubit, CreateCharacterState>(
      listener: (context, state) {
        if (state.autofillStamp != _lastAutofillStamp) {
          _lastAutofillStamp = state.autofillStamp;
          _syncFromState(state);
        }
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
                _Header(onBack: _step == 0 ? null : _back),
                _CharStepProgress(step: _step),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _buildStep(context, cubit, state),
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _ErrorText(state.error!),
                  ),
                _CharNavBar(
                  step: _step,
                  canProceed: _step != 0 || state.canCreate,
                  canCreate: state.canCreate,
                  busy: state.isSubmitting,
                  onBack: _back,
                  onNext: _next,
                  onCreate: cubit.create,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(
      BuildContext context, CreateCharacterCubit cubit, CreateCharacterState state) {
    switch (_step) {
      case 0:
        return _stepWhoTheyAre(cubit, state);
      case 1:
        return _stepVoiceStory(cubit, state);
      default:
        return _stepPortrait(cubit, state);
    }
  }

  Widget _stepWhoTheyAre(CreateCharacterCubit cubit, CreateCharacterState state) {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create someone to talk to. They\'ll remember your conversations and '
            'grow with them.',
            style:
                EverloreTheme.ui(size: 13, color: EverloreTheme.ash, height: 1.5),
          ),
          const SizedBox(height: 16),
          AutofillLauncher(
            target: 'character',
            busy: state.isAutofilling,
            error: state.autofillError,
            isNsfwCapable: state.isNsfwCapable,
            onSetNsfw: cubit.setNsfw,
            onGenerate: (brief) => cubit.autofillAll(brief: brief),
          ),
          _field(
            label: 'Name',
            hint: 'e.g. Mira, Captain Vale, Aria…',
            controller: _nameCtrl,
            required: true,
            onChanged: cubit.setName,
            textCapitalization: TextCapitalization.words,
          ),
          _field(
            label: 'Tagline',
            hint: 'A short line — who are they at a glance?',
            controller: _taglineCtrl,
            required: true,
            onChanged: cubit.setTagline,
            textCapitalization: TextCapitalization.sentences,
          ),
          _field(
            label: 'Personality',
            hint:
                'How do they think, talk, and treat you? Their mood, quirks, and relationship to you.',
            controller: _personaCtrl,
            required: true,
            onChanged: cubit.setPersona,
            maxLines: 6,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          _MatureToggle(value: state.isNsfwCapable, onChanged: cubit.setNsfw),
        ],
      ),
    );
  }

  Widget _stepVoiceStory(CreateCharacterCubit cubit, CreateCharacterState state) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How they sound, and what they always know. All optional — skip and '
            'they\'ll still come alive.',
            style:
                EverloreTheme.ui(size: 13, color: EverloreTheme.ash, height: 1.5),
          ),
          const SizedBox(height: 20),
          VoicePicker(
            selected: state.narrativeStyle,
            onSelect: cubit.setNarrativeStyle,
            notes: state.styleNotes,
            onNotesChanged: cubit.setStyleNotes,
          ),
          _field(
            label: 'Greeting',
            hint: 'The first thing they say when the chat opens.',
            controller: _greetingCtrl,
            onChanged: cubit.setGreeting,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          _field(
            label: 'Backstory & world',
            hint:
                'Anything they should always know — their past, setting, relationships.',
            controller: _backstoryCtrl,
            onChanged: cubit.setBackstory,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _stepPortrait(CreateCharacterCubit cubit, CreateCharacterState state) {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'An optional portrait — shown on their card and as the chat '
            'background. Drafted by “Generate with AI”, or write your own.',
            style:
                EverloreTheme.ui(size: 13, color: EverloreTheme.ash, height: 1.5),
          ),
          const SizedBox(height: 20),
          ImageForge(
            imageUrl: state.imageUrl,
            prompt: state.imagePrompt,
            busy: state.isImageBusy,
            error: state.imageError,
            onPromptChanged: cubit.setImagePrompt,
            onGenerate: cubit.generateImage,
            promptFieldKey: ValueKey('cimg_${state.autofillStamp}'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    TextEditingController? controller,
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
                Text('  *',
                    style:
                        EverloreTheme.ui(size: 13, color: EverloreTheme.gold)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
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
  final VoidCallback? onBack;
  const _Header({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (onBack != null) {
                onBack!();
              } else {
                context.canPop() ? context.pop() : context.go('/');
              }
            },
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: EverloreTheme.ash),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.person_add_alt_1,
              color: EverloreTheme.violetBright, size: 16),
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

class _CharStepProgress extends StatelessWidget {
  final int step;
  const _CharStepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _charStepNames[step],
            style: EverloreTheme.ui(
                size: 18, color: EverloreTheme.parchment, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_charStepCount, (i) {
              final filled = i <= step;
              final active = i == step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: active ? 3 : 2,
                  margin: EdgeInsets.only(right: i < _charStepCount - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: filled
                        ? (active
                            ? EverloreTheme.violetBright
                            : EverloreTheme.violet)
                        : EverloreTheme.void4,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
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
                  Text(
                      'Allows mature themes if you enable them in preferences. Also steers “Generate with AI”.',
                      style:
                          EverloreTheme.ui(size: 12, color: EverloreTheme.ash)),
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

class _CharNavBar extends StatelessWidget {
  final int step;
  final bool canProceed;
  final bool canCreate;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onCreate;

  const _CharNavBar({
    required this.step,
    required this.canProceed,
    required this.canCreate,
    required this.busy,
    required this.onBack,
    required this.onNext,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == _charStepCount - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
          top: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: EverloreTheme.void3,
                  border: Border.all(
                      color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text('Back',
                      style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.ash,
                          weight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: isLast
                ? _PrimaryBtn(
                    enabled: canCreate && !busy,
                    busy: busy,
                    icon: Icons.chat_bubble_outline,
                    label: 'Create & Chat',
                    onTap: onCreate,
                  )
                : _PrimaryBtn(
                    enabled: canProceed,
                    busy: false,
                    icon: Icons.arrow_forward,
                    label: 'Continue',
                    onTap: onNext,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.enabled,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
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
                    Text(label,
                        style: EverloreTheme.ui(
                            size: 15,
                            color: enabled
                                ? EverloreTheme.parchment
                                : EverloreTheme.ash,
                            weight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Icon(icon,
                        size: 18,
                        color: enabled
                            ? EverloreTheme.parchment
                            : EverloreTheme.ash),
                  ],
                ),
        ),
      ),
    );
  }
}
