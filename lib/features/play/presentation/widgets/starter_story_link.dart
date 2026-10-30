import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:everlore/app/theme/nexus_theme.dart';

/// A quiet, subtle link shown on the first story after onboarding, allowing
/// a player who doesn't like the starter pick to browse other stories.
class StarterStoryLink extends StatelessWidget {
  final VoidCallback? onTap;

  const StarterStoryLink({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44.0, minWidth: 44.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap ?? () => context.go('/discover'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pick a different story',
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.ash,
                    weight: FontWeight.w500,
                    spacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: EverloreTheme.ash.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
