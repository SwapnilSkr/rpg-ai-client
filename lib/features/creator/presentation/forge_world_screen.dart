import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/forge_world_cubit.dart';
import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/world_template.dart';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────

class ForgeWorldScreen extends StatefulWidget {
  final WorldTemplate? existing;

  const ForgeWorldScreen({super.key, this.existing});

  @override
  State<ForgeWorldScreen> createState() => _ForgeWorldScreenState();
}

class _ForgeWorldScreenState extends State<ForgeWorldScreen> {
  late final ForgeWorldCubit _cubit;

  // Step 0 controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  // Step 1 controllers
  late final TextEditingController _seedCtrl;

  // Step 2 controllers
  late final TextEditingController _loreCtrl;
  late final TextEditingController _tagInputCtrl;

  // Step 4 controllers
  late final TextEditingController _modelLogicCtrl;
  late final TextEditingController _modelNarrSfwCtrl;
  late final TextEditingController _modelNarrNsfwCtrl;
  late final TextEditingController _modelSummaryCtrl;

  @override
  void initState() {
    super.initState();
    _cubit = ForgeWorldCubit(existing: widget.existing);
    final s = _cubit.state;
    _titleCtrl = TextEditingController(text: s.title);
    _descCtrl = TextEditingController(text: s.description);
    _seedCtrl = TextEditingController(text: s.seedPrompt);
    _loreCtrl = TextEditingController(text: s.globalLore);
    _tagInputCtrl = TextEditingController();
    _modelLogicCtrl = TextEditingController(text: s.modelLogic);
    _modelNarrSfwCtrl = TextEditingController(text: s.modelNarrationSfw);
    _modelNarrNsfwCtrl = TextEditingController(text: s.modelNarrationNsfw);
    _modelSummaryCtrl = TextEditingController(text: s.modelSummary);
  }

  @override
  void dispose() {
    _cubit.close();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _seedCtrl.dispose();
    _loreCtrl.dispose();
    _tagInputCtrl.dispose();
    _modelLogicCtrl.dispose();
    _modelNarrSfwCtrl.dispose();
    _modelNarrNsfwCtrl.dispose();
    _modelSummaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<ForgeWorldCubit, ForgeWorldState>(
        listener: (context, state) {
          if (state.result != null) {
            context.go('/my-worlds');
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: EverloreTheme.void1,
            body: SafeArea(
              child: Column(
                children: [
                  _ForgeHeader(
                    step: state.step,
                    isEditing: widget.existing != null,
                    onBack: () {
                      if (state.step == 0) {
                        context.pop();
                      } else {
                        _cubit.prevStep();
                      }
                    },
                  ),
                  _StepProgress(step: state.step),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _buildStep(context, state),
                    ),
                  ),
                  if (state.error != null)
                    _ErrorBar(
                      message: state.error!,
                      onDismiss: () =>
                          context.read<ForgeWorldCubit>().clearError(),
                    ),
                  _ForgeNavBar(
                    step: state.step,
                    canProceed: state.canProceed,
                    isSubmitting: state.isSubmitting,
                    onNext: () => _cubit.nextStep(),
                    onForge: () => _cubit.forge(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep(BuildContext context, ForgeWorldState state) {
    switch (state.step) {
      case 0:
        return _Step0Essence(
          key: const ValueKey(0),
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          cubit: _cubit,
          state: state,
        );
      case 1:
        return _Step1Voice(
          key: const ValueKey(1),
          seedCtrl: _seedCtrl,
          cubit: _cubit,
          state: state,
        );
      case 2:
        return _Step2Lore(
          key: const ValueKey(2),
          loreCtrl: _loreCtrl,
          tagInputCtrl: _tagInputCtrl,
          cubit: _cubit,
          state: state,
        );
      case 3:
        return _Step3Stats(
          key: const ValueKey(3),
          cubit: _cubit,
          state: state,
        );
      case 4:
        return _Step4Engine(
          key: const ValueKey(4),
          modelLogicCtrl: _modelLogicCtrl,
          modelNarrSfwCtrl: _modelNarrSfwCtrl,
          modelNarrNsfwCtrl: _modelNarrNsfwCtrl,
          modelSummaryCtrl: _modelSummaryCtrl,
          cubit: _cubit,
          state: state,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────

const _stepNames = [
  'THE ESSENCE',
  "ORACLE'S VOICE",
  'ANCIENT LORE',
  'VITAL FORCES',
  'ARCANE ENGINE',
];

class _ForgeHeader extends StatelessWidget {
  final int step;
  final bool isEditing;
  final VoidCallback onBack;

  const _ForgeHeader(
      {required this.step, required this.isEditing, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: EverloreTheme.ash),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_fix_high,
              color: EverloreTheme.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            isEditing ? 'EDIT WORLD' : 'FORGE WORLD',
            style: const TextStyle(
              color: EverloreTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
          const Spacer(),
          Text(
            '${step + 1} / 5',
            style: const TextStyle(
                color: EverloreTheme.ash, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step progress bar
// ─────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int step;
  const _StepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepNames[step],
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              final filled = i <= step;
              final active = i == step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: active ? 3 : 2,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: filled
                        ? (active ? EverloreTheme.gold : EverloreTheme.goldDim)
                        : EverloreTheme.void4,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color:
                                  EverloreTheme.gold.withValues(alpha: 0.5),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom nav bar
// ─────────────────────────────────────────────

class _ForgeNavBar extends StatelessWidget {
  final int step;
  final bool canProceed;
  final bool isSubmitting;
  final VoidCallback onNext;
  final VoidCallback onForge;

  const _ForgeNavBar({
    required this.step,
    required this.canProceed,
    required this.isSubmitting,
    required this.onNext,
    required this.onForge,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == 4;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(
            top: BorderSide(
                color: EverloreTheme.goldDim.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            _NavSecondaryBtn(
              label: 'Back',
              onTap: () => context.read<ForgeWorldCubit>().prevStep(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: isLast
                ? _ForgeButton(
                    isSubmitting: isSubmitting, onForge: onForge)
                : _NextButton(
                    canProceed: canProceed, onNext: onNext),
          ),
        ],
      ),
    );
  }
}

class _NavSecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavSecondaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: EverloreTheme.void3,
          border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Text('Back',
              style: TextStyle(
                  color: EverloreTheme.ash,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool canProceed;
  final VoidCallback onNext;
  const _NextButton({required this.canProceed, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canProceed ? onNext : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: canProceed
              ? const LinearGradient(
                  colors: [EverloreTheme.goldGlow, EverloreTheme.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canProceed ? null : EverloreTheme.void3,
          boxShadow: canProceed
              ? [
                  BoxShadow(
                    color: EverloreTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 14,
                  )
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue',
                style: TextStyle(
                  color: canProceed
                      ? EverloreTheme.void1
                      : EverloreTheme.ash,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color:
                    canProceed ? EverloreTheme.void1 : EverloreTheme.ash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgeButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onForge;
  const _ForgeButton(
      {required this.isSubmitting, required this.onForge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSubmitting ? null : onForge,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFF0C86A), Color(0xFFD4A843), Color(0xFF8A6820)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: EverloreTheme.gold.withValues(alpha: 0.45),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EverloreTheme.void1,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high,
                        color: EverloreTheme.void1, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'FORGE THIS WORLD',
                      style: TextStyle(
                        color: EverloreTheme.void1,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error bar
// ─────────────────────────────────────────────

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: EverloreTheme.crimson, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: EverloreTheme.crimson, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                color: EverloreTheme.crimson, size: 16),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared form helpers
// ─────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final bool required;
  const _FormLabel(
      {required this.label, this.hint, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*',
                  style: TextStyle(
                      color: EverloreTheme.gold, fontSize: 13)),
            ],
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!,
              style: const TextStyle(
                  color: EverloreTheme.ash, fontSize: 11, height: 1.4)),
        ],
      ],
    );
  }
}

InputDecoration _fieldDecoration(String placeholder) {
  return InputDecoration(
    hintText: placeholder,
    hintStyle: const TextStyle(color: EverloreTheme.ash, fontSize: 14),
    filled: true,
    fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
    ),
  );
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? activeColor.withValues(alpha: 0.08)
              : EverloreTheme.void2,
          border: Border.all(
            color: value
                ? activeColor.withValues(alpha: 0.45)
                : EverloreTheme.goldDim.withValues(alpha: 0.15),
            width: value ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value
                    ? activeColor.withValues(alpha: 0.12)
                    : EverloreTheme.void3,
              ),
              child: Icon(icon,
                  color: value ? activeColor : EverloreTheme.ash, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: value
                            ? EverloreTheme.parchment
                            : EverloreTheme.ash,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 12,
                          height: 1.3)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color:
                    value ? activeColor : EverloreTheme.void4,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EverloreTheme.parchment,
                    boxShadow: [
                      if (value)
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        )
                    ],
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

// ─────────────────────────────────────────────
// Step 0 — The Essence
// ─────────────────────────────────────────────

class _Step0Essence extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final ForgeWorldCubit cubit;
  final ForgeWorldState state;

  const _Step0Essence({
    super.key,
    required this.titleCtrl,
    required this.descCtrl,
    required this.cubit,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.auto_stories,
            text:
                'Define what this world is. Its name and description are the first things adventurers will see.',
          ),
          const SizedBox(height: 24),
          const _FormLabel(
            label: 'World Name',
            hint: 'The name adventurers will know it by',
            required: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtrl,
            onChanged: cubit.setTitle,
            style: const TextStyle(
                color: EverloreTheme.parchment, fontSize: 15),
            decoration: _fieldDecoration(
                'e.g. The Shattered Kingdoms, Veilborn...'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          const _FormLabel(
            label: 'World Description',
            hint:
                'A compelling summary shown to adventurers in the world browser',
            required: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            onChanged: cubit.setDescription,
            style: const TextStyle(
                color: EverloreTheme.parchment, fontSize: 14, height: 1.5),
            decoration: _fieldDecoration(
                'Describe the world, its tone, and what kind of adventure awaits...'),
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          const Text(
            'WORLD TYPE',
            style: TextStyle(
              color: EverloreTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            icon: Icons.psychology_alt,
            title: 'Conscious Soul',
            subtitle:
                'The world has an AI persona — it thinks, feels, and reacts as a character within the story',
            value: state.isSentient,
            activeColor: EverloreTheme.violet,
            onChanged: cubit.setIsSentient,
          ),
          const SizedBox(height: 8),
          _ToggleCard(
            icon: Icons.auto_stories,
            title: 'Game Master',
            subtitle:
                'The AI acts as a neutral narrator, orchestrating the world and responding to player choices',
            value: !state.isSentient,
            activeColor: EverloreTheme.cyan,
            onChanged: (v) => cubit.setIsSentient(!v),
          ),
          const SizedBox(height: 24),
          const Text(
            'CONTENT',
            style: TextStyle(
              color: EverloreTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          _ToggleCard(
            icon: Icons.shield_outlined,
            title: 'Mature Realm',
            subtitle:
                'Enables mature themes and content for players who have enabled it in their preferences',
            value: state.isNsfwCapable,
            activeColor: EverloreTheme.crimson,
            onChanged: cubit.setIsNsfwCapable,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 1 — Oracle's Voice
// ─────────────────────────────────────────────

class _Step1Voice extends StatelessWidget {
  final TextEditingController seedCtrl;
  final ForgeWorldCubit cubit;
  final ForgeWorldState state;

  const _Step1Voice({
    super.key,
    required this.seedCtrl,
    required this.cubit,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.record_voice_over,
            text:
                "The Oracle's Voice is the AI's core instruction set — it defines the narrator's personality, tone, rules, and the soul of your world.",
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: EverloreTheme.violet.withValues(alpha: 0.08),
              border: Border.all(
                  color: EverloreTheme.violetDim.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: EverloreTheme.violetBright, size: 14),
                    SizedBox(width: 6),
                    Text('Tips for a powerful voice',
                        style: TextStyle(
                            color: EverloreTheme.violetBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                _Tip(text: 'Describe the narrator\'s tone (grim, whimsical, epic...)'),
                _Tip(text: 'State the genre and setting explicitly'),
                _Tip(text: 'List what the narrator should and should not do'),
                _Tip(text: 'Include any special rules or game mechanics'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _FormLabel(
            label: "Oracle's Voice",
            hint: 'System prompt — the AI reads this before every response',
            required: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: seedCtrl,
            onChanged: cubit.setSeedPrompt,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 13,
              height: 1.6,
            ),
            decoration: _fieldDecoration(
              'You are the narrator of [World Name], a dark fantasy realm where...\n\nYour tone is grim and foreboding. You describe actions with visceral detail. You never...',
            ),
            maxLines: 14,
            minLines: 10,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          _CharCount(
              current: state.seedPrompt.trim().length,
              min: 10,
              max: 10000),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('·  ',
              style:
                  TextStyle(color: EverloreTheme.violetBright, fontSize: 12)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: EverloreTheme.ash, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 2 — Ancient Lore
// ─────────────────────────────────────────────

class _Step2Lore extends StatefulWidget {
  final TextEditingController loreCtrl;
  final TextEditingController tagInputCtrl;
  final ForgeWorldCubit cubit;
  final ForgeWorldState state;

  const _Step2Lore({
    super.key,
    required this.loreCtrl,
    required this.tagInputCtrl,
    required this.cubit,
    required this.state,
  });

  @override
  State<_Step2Lore> createState() => _Step2LoreState();
}

class _Step2LoreState extends State<_Step2Lore> {
  void _addTag() {
    final text = widget.tagInputCtrl.text.trim();
    if (text.isNotEmpty) {
      widget.cubit.addTag(text);
      widget.tagInputCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    const suggested = [
      'combat',
      'dialogue',
      'exploration',
      'mystery',
      'romance',
      'horror',
      'politics',
      'magic',
      'survival',
      'stealth',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.history_edu,
            text:
                'The Ancient Lore is your world\'s foundational knowledge — history, geography, factions, mythology. The AI uses this as its encyclopedia.',
          ),
          const SizedBox(height: 20),
          const _FormLabel(
            label: 'Ancient Lore',
            hint: 'World history, lore, geography, factions, rules of magic...',
            required: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.loreCtrl,
            onChanged: widget.cubit.setGlobalLore,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 13,
              height: 1.6,
            ),
            decoration: _fieldDecoration(
              'In the age before the Sundering, the realm of Eldrath was unified under...\n\nThe five great factions are...\n\nMagic in this world works by...',
            ),
            maxLines: 14,
            minLines: 10,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          _CharCount(
            current: widget.state.globalLore.trim().length,
            min: 10,
            max: 50000,
          ),
          const SizedBox(height: 24),
          const Text(
            'STORY THREADS',
            style: TextStyle(
              color: EverloreTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tags that describe the kinds of scenes adventurers will encounter',
            style: TextStyle(color: EverloreTheme.ash, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Tag chips
          if (widget.state.sceneTags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.state.sceneTags
                  .map((tag) => _TagChip(
                        label: tag,
                        onRemove: () => widget.cubit.removeTag(tag),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Tag input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.tagInputCtrl,
                  style: const TextStyle(
                      color: EverloreTheme.parchment, fontSize: 14),
                  decoration: _fieldDecoration('Add a thread (e.g. combat)'),
                  onSubmitted: (_) => _addTag(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: EverloreTheme.goldDim.withValues(alpha: 0.15),
                    border: Border.all(
                        color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.add,
                      color: EverloreTheme.gold, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Suggested tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggested
                .where((t) => !widget.state.sceneTags.contains(t))
                .map((tag) => GestureDetector(
                      onTap: () => widget.cubit.addTag(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: EverloreTheme.void3,
                          border: Border.all(
                              color:
                                  EverloreTheme.void4.withValues(alpha: 0.8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add,
                                size: 11, color: EverloreTheme.ash),
                            const SizedBox(width: 4),
                            Text(tag,
                                style: const TextStyle(
                                    color: EverloreTheme.ash, fontSize: 12)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: EverloreTheme.gold.withValues(alpha: 0.1),
        border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: EverloreTheme.gold, fontSize: 12)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 12, color: EverloreTheme.goldDim),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 3 — Vital Forces (Stats)
// ─────────────────────────────────────────────

class _Step3Stats extends StatelessWidget {
  final ForgeWorldCubit cubit;
  final ForgeWorldState state;

  const _Step3Stats({
    super.key,
    required this.cubit,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.bar_chart,
            text:
                'Vital Forces are the measurable attributes that track adventurer progress. Health, mana, honour — define any stats your world tracks.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: EverloreTheme.void2,
              border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: EverloreTheme.ash),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stats are optional. Worlds without stats focus purely on narrative.',
                    style:
                        TextStyle(color: EverloreTheme.ash, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Quick-add presets
          const Text('QUICK ADD',
              style: TextStyle(
                  color: EverloreTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          _PresetButtons(cubit: cubit, existing: state.stats),
          const SizedBox(height: 20),
          // Stat list
          if (state.stats.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '${state.stats.length} VITAL ${state.stats.length == 1 ? "FORCE" : "FORCES"}',
                  style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...state.stats.asMap().entries.map((e) => _StatCard(
                  entry: e.value,
                  index: e.key,
                  cubit: cubit,
                )),
            const SizedBox(height: 12),
          ],
          // Add custom stat
          GestureDetector(
            onTap: () => _showStatEditor(context, cubit, null, null),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
                color: EverloreTheme.void2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: EverloreTheme.gold, size: 18),
                  SizedBox(width: 8),
                  Text('Add Custom Force',
                      style: TextStyle(
                          color: EverloreTheme.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _showStatEditor(
    BuildContext context,
    ForgeWorldCubit cubit,
    StatEntry? existing,
    int? index,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StatEditorSheet(
        existing: existing,
        onSave: (stat) {
          if (index != null) {
            cubit.updateStat(index, stat);
          } else {
            cubit.addStat(stat);
          }
        },
      ),
    );
  }
}

class _PresetButtons extends StatelessWidget {
  final ForgeWorldCubit cubit;
  final List<StatEntry> existing;

  const _PresetButtons({required this.cubit, required this.existing});

  static const _presets = [
    ('health', 'Health', Icons.favorite_outline, 100, 0, 100),
    ('mana', 'Mana', Icons.bolt, 100, 0, 100),
    ('sanity', 'Sanity', Icons.psychology, 100, 0, 100),
    ('honour', 'Honour', Icons.shield_outlined, 50, 0, 100),
    ('gold', 'Gold', Icons.monetization_on_outlined, 0, 0, 999),
    ('strength', 'Strength', Icons.fitness_center, 10, 1, 20),
  ];

  @override
  Widget build(BuildContext context) {
    final existingNames = existing.map((e) => e.name).toSet();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((p) {
        final alreadyAdded = existingNames.contains(p.$1);
        return GestureDetector(
          onTap: alreadyAdded
              ? null
              : () => cubit.addStat(StatEntry(
                    name: p.$1,
                    defaultValue: p.$4,
                    min: p.$5,
                    max: p.$6,
                    description: '',
                  )),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: alreadyAdded
                  ? EverloreTheme.verdant.withValues(alpha: 0.1)
                  : EverloreTheme.void3,
              border: Border.all(
                color: alreadyAdded
                    ? EverloreTheme.verdant.withValues(alpha: 0.4)
                    : EverloreTheme.goldDim.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(alreadyAdded ? Icons.check : p.$3,
                    size: 14,
                    color: alreadyAdded
                        ? EverloreTheme.verdant
                        : EverloreTheme.ash),
                const SizedBox(width: 6),
                Text(p.$2,
                    style: TextStyle(
                      color: alreadyAdded
                          ? EverloreTheme.verdant
                          : EverloreTheme.ash,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final StatEntry entry;
  final int index;
  final ForgeWorldCubit cubit;

  const _StatCard(
      {required this.entry, required this.index, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: EverloreTheme.void2,
        border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: EverloreTheme.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.min} – ${entry.max}  ·  default: ${entry.defaultValue}',
                  style: const TextStyle(
                      color: EverloreTheme.ash, fontSize: 11),
                ),
                if (entry.description.isNotEmpty)
                  Text(
                    entry.description,
                    style: const TextStyle(
                        color: EverloreTheme.ash, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Edit
          GestureDetector(
            onTap: () => _Step3Stats._showStatEditor(
                context, cubit, entry, index),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.edit_outlined,
                  size: 16, color: EverloreTheme.ash),
            ),
          ),
          // Delete
          GestureDetector(
            onTap: () => cubit.removeStat(index),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.delete_outline,
                  size: 16, color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stat editor bottom sheet
// ─────────────────────────────────────────────

class _StatEditorSheet extends StatefulWidget {
  final StatEntry? existing;
  final ValueChanged<StatEntry> onSave;

  const _StatEditorSheet({this.existing, required this.onSave});

  @override
  State<_StatEditorSheet> createState() => _StatEditorSheetState();
}

class _StatEditorSheetState extends State<_StatEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _defaultCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _descCtrl;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _defaultCtrl =
        TextEditingController(text: (e?.defaultValue ?? 50).toString());
    _minCtrl = TextEditingController(text: (e?.min ?? 0).toString());
    _maxCtrl = TextEditingController(text: (e?.max ?? 100).toString());
    _descCtrl = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _defaultCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    final defaultVal = num.tryParse(_defaultCtrl.text) ?? 50;
    final min = num.tryParse(_minCtrl.text) ?? 0;
    final max = num.tryParse(_maxCtrl.text) ?? 100;
    widget.onSave(StatEntry(
      name: name,
      defaultValue: defaultVal,
      min: min,
      max: max,
      description: _descCtrl.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EverloreTheme.void4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing != null ? 'Edit Vital Force' : 'New Vital Force',
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          // Name
          const _FormLabel(label: 'Name', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() => _nameError = null),
            style: const TextStyle(
                color: EverloreTheme.parchment, fontSize: 14),
            decoration: _fieldDecoration('health, mana, honour...').copyWith(
              errorText: _nameError,
              errorStyle: const TextStyle(color: EverloreTheme.crimson),
            ),
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 16),
          // Range row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel(label: 'Min'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _minCtrl,
                      style: const TextStyle(
                          color: EverloreTheme.parchment, fontSize: 14),
                      decoration: _fieldDecoration('0'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel(label: 'Max'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _maxCtrl,
                      style: const TextStyle(
                          color: EverloreTheme.parchment, fontSize: 14),
                      decoration: _fieldDecoration('100'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormLabel(label: 'Default'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _defaultCtrl,
                      style: const TextStyle(
                          color: EverloreTheme.parchment, fontSize: 14),
                      decoration: _fieldDecoration('50'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _FormLabel(label: 'Description', hint: 'Optional'),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(
                color: EverloreTheme.parchment, fontSize: 14),
            decoration: _fieldDecoration('e.g. The life force of the adventurer'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(widget.existing != null
                  ? 'Update Force'
                  : 'Add Force'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 4 — Arcane Engine (Advanced)
// ─────────────────────────────────────────────

class _Step4Engine extends StatefulWidget {
  final TextEditingController modelLogicCtrl;
  final TextEditingController modelNarrSfwCtrl;
  final TextEditingController modelNarrNsfwCtrl;
  final TextEditingController modelSummaryCtrl;
  final ForgeWorldCubit cubit;
  final ForgeWorldState state;

  const _Step4Engine({
    super.key,
    required this.modelLogicCtrl,
    required this.modelNarrSfwCtrl,
    required this.modelNarrNsfwCtrl,
    required this.modelSummaryCtrl,
    required this.cubit,
    required this.state,
  });

  @override
  State<_Step4Engine> createState() => _Step4EngineState();
}

class _Step4EngineState extends State<_Step4Engine> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.settings_suggest,
            text:
                'Fine-tune the arcane engine that powers your world. The defaults work great for most worlds.',
          ),
          const SizedBox(height: 20),
          // Memory depth
          const _FormLabel(
            label: 'Memory Depth',
            hint:
                'How many Echoes the AI considers when generating responses (5–50)',
          ),
          const SizedBox(height: 10),
          _SliderControl(
            value: widget.state.maxContextMemories.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: widget.state.maxContextMemories.toString(),
            color: EverloreTheme.violet,
            onChanged: (v) =>
                widget.cubit.setMaxContextMemories(v.round()),
          ),
          _SliderLabels(
              left: '5 (shallow)', right: '50 (deep)'),
          const SizedBox(height: 20),
          // Lore recall
          const _FormLabel(
            label: 'Lore Recall',
            hint:
                'How many lore passages the AI retrieves from Ancient Lore per response (3–20)',
          ),
          const SizedBox(height: 10),
          _SliderControl(
            value: widget.state.maxLoreResults.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            label: widget.state.maxLoreResults.toString(),
            color: EverloreTheme.cyan,
            onChanged: (v) =>
                widget.cubit.setMaxLoreResults(v.round()),
          ),
          _SliderLabels(left: '3 (focused)', right: '20 (expansive)'),
          const SizedBox(height: 24),
          // Advanced toggle
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: EverloreTheme.void2,
                border: Border.all(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune,
                      color: EverloreTheme.ash, size: 16),
                  const SizedBox(width: 8),
                  const Text('Advanced Model Settings',
                      style: TextStyle(
                          color: EverloreTheme.ash, fontSize: 14)),
                  const Spacer(),
                  Icon(
                    _showAdvanced
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: EverloreTheme.ash,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: EverloreTheme.void2,
                border: Border.all(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These models power different aspects of your world. Only change if you know what you\'re doing.',
                    style: TextStyle(
                        color: EverloreTheme.ash,
                        fontSize: 12,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  _ModelField(
                    label: 'Logic Model',
                    hint: 'Handles game mechanics and state',
                    controller: widget.modelLogicCtrl,
                    onChanged: widget.cubit.setModelLogic,
                  ),
                  const SizedBox(height: 12),
                  _ModelField(
                    label: 'Narration Model (Standard)',
                    hint: 'Generates story text for most content',
                    controller: widget.modelNarrSfwCtrl,
                    onChanged: widget.cubit.setModelNarrationSfw,
                  ),
                  if (widget.state.isNsfwCapable) ...[
                    const SizedBox(height: 12),
                    _ModelField(
                      label: 'Narration Model (Mature)',
                      hint: 'Used when mature content is requested',
                      controller: widget.modelNarrNsfwCtrl,
                      onChanged: widget.cubit.setModelNarrationNsfw,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ModelField(
                    label: 'Summary Model',
                    hint: 'Condenses long histories for context',
                    controller: widget.modelSummaryCtrl,
                    onChanged: widget.cubit.setModelSummary,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          // Summary card before forge
          _ForgeSummary(state: widget.state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ModelField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
              color: EverloreTheme.parchment, fontSize: 13),
          decoration: _fieldDecoration(hint),
        ),
      ],
    );
  }
}

class _SliderControl extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: color,
        inactiveTrackColor: EverloreTheme.void4,
        thumbColor: color,
        overlayColor: color.withValues(alpha: 0.15),
        valueIndicatorColor: color,
        valueIndicatorTextStyle:
            const TextStyle(color: EverloreTheme.void1, fontSize: 12),
        trackHeight: 3,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}

class _SliderLabels extends StatelessWidget {
  final String left;
  final String right;
  const _SliderLabels({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left,
              style: const TextStyle(
                  color: EverloreTheme.ash, fontSize: 10)),
          Text(right,
              style: const TextStyle(
                  color: EverloreTheme.ash, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ForgeSummary extends StatelessWidget {
  final ForgeWorldState state;
  const _ForgeSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A38), Color(0xFF0F0F28)],
        ),
        border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: EverloreTheme.gold.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_fix_high,
                  color: EverloreTheme.gold, size: 16),
              SizedBox(width: 8),
              Text('READY TO FORGE',
                  style: TextStyle(
                      color: EverloreTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'World',
            value: state.title.isNotEmpty ? state.title : '—',
          ),
          _SummaryRow(
            label: 'Type',
            value:
                state.isSentient ? 'Conscious Soul' : 'Game Master',
          ),
          _SummaryRow(
            label: 'Content',
            value: state.isNsfwCapable ? 'Mature' : 'Standard',
          ),
          _SummaryRow(
            label: 'Stats',
            value: state.stats.isEmpty
                ? 'None (narrative only)'
                : '${state.stats.length} defined',
          ),
          _SummaryRow(
            label: 'Scene Threads',
            value: state.sceneTags.isEmpty
                ? 'None'
                : state.sceneTags.join(', '),
          ),
          _SummaryRow(
            label: 'Memory Depth',
            value: '${state.maxContextMemories} Echoes',
          ),
          _SummaryRow(
            label: 'Lore Recall',
            value: '${state.maxLoreResults} passages',
            isLast: true,
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF252548), height: 1),
          const SizedBox(height: 10),
          const Text(
            'Your world will be saved as a draft. You can review and publish it from My Worlds.',
            style: TextStyle(
                color: EverloreTheme.ash, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _SummaryRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: EverloreTheme.ash, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────

class _StepIntro extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StepIntro({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: EverloreTheme.void2,
        border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EverloreTheme.goldDim, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: EverloreTheme.ash, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharCount extends StatelessWidget {
  final int current;
  final int min;
  final int max;
  const _CharCount(
      {required this.current, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final ok = current >= min;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$current / $max',
          style: TextStyle(
            color: ok ? EverloreTheme.ash : EverloreTheme.ember,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
