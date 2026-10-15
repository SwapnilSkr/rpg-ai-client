import 'package:flutter/material.dart';

import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/ink_mark.dart';

class TheInkRestsDialog extends StatelessWidget {
  final String? resetsAt;
  final VoidCallback onBackToWorlds;

  const TheInkRestsDialog({
    super.key,
    required this.onBackToWorlds,
    this.resetsAt,
  });

  String? _formatLocalTime(BuildContext context) {
    final raw = resetsAt;
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim())?.toLocal();
    if (parsed == null) return null;
    try {
      return TimeOfDay.fromDateTime(parsed).format(context);
    } catch (_) {}
    final hour = parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = isPm ? 'PM' : 'AM';
    return '$h:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final localTime = _formatLocalTime(context);
    return Material(
      color: EverloreTheme.void0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/ink-muse.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.06),
                  EverloreTheme.void0.withValues(alpha: 0.18),
                  EverloreTheme.void0.withValues(alpha: 0.68),
                  EverloreTheme.void0.withValues(alpha: 0.96),
                  EverloreTheme.void0,
                ],
                stops: const [0, 0.34, 0.6, 0.78, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 108,
                    height: 108,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          EverloreTheme.gold.withValues(alpha: 0.20),
                          EverloreTheme.gold.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                    child: const InkMark(size: 50, color: EverloreTheme.gold),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'The Ink Rests',
                    textAlign: TextAlign.center,
                    style: EverloreTheme.serifDisplay(
                      size: 30,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w600,
                      spacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 54,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          EverloreTheme.goldDim.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Text(
                      'Your story has run long today, and the quill needs a moment. Everything you\'ve written is kept exactly where you left it.',
                      textAlign: TextAlign.center,
                      style: EverloreTheme.aiText.copyWith(
                        fontSize: 16,
                        color: EverloreTheme.parchment.withValues(alpha: 0.88),
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (localTime != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Your tale continues at $localTime',
                      textAlign: TextAlign.center,
                      style: EverloreTheme.ui(
                        size: 13,
                        color: EverloreTheme.goldDim,
                        weight: FontWeight.w600,
                        spacing: 0.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onBackToWorlds,
                      style: FilledButton.styleFrom(
                        backgroundColor: EverloreTheme.gold,
                        foregroundColor: EverloreTheme.void0,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Back to my worlds',
                        style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.void0,
                          weight: FontWeight.w700,
                          spacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
