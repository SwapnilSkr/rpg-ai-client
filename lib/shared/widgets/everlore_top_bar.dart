import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/nexus_theme.dart';
import 'neu.dart';

class EverloreTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showProfile;

  const EverloreTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 14, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(
            color: EverloreTheme.goldDim.withValues(alpha: 0.14),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const ForgeMark(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EVERLORE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cinzel(
                    color: EverloreTheme.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 17,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                  ),
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
          if (showProfile) ...[
            const SizedBox(width: 8),
            EverloreTopBarIcon(
              icon: Icons.person_outline_rounded,
              tooltip: 'Profile',
              onTap: () => context.push('/profile'),
            ),
          ],
        ],
      ),
    );
  }
}

class EverloreTopBarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isLoading;

  const EverloreTopBarIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [EverloreTheme.void3, EverloreTheme.void1],
            ),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: EverloreTheme.goldDim,
                  ),
                )
              : Icon(icon, color: EverloreTheme.gold, size: 19),
        ),
      ),
    );
  }
}
