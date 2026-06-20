import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/nexus_theme.dart';
import '../app_icons.dart';

/// Persistent shell scaffold: hosts the four nav branches (Explore · Realms ·
/// Worlds · Personas) and the single, always-on [EverloreNavBar]. The branches keep
/// their own navigation stacks (state preserved across tab switches); detail
/// screens push over this shell at the root, so back / OS-back behave.
class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ScaffoldWithNavBar({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      extendBody: true, // content flows under the floating glass bar
      body: shell,
      bottomNavigationBar: EverloreNavBar(
        currentIndex: shell.currentIndex,
        onSelect: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        onCreate: () => showCreateChooser(context),
      ),
    );
  }
}

/// One nav slot (a branch tab). `null` in the layout list = the center Create.
class _Slot {
  final String icon;
  final String label;
  final int branch;
  const _Slot(this.icon, this.label, this.branch);
}

/// Floating, glassy bottom nav (iOS-style): detached from the bottom edge,
/// rounded, with a backdrop blur and a forged champagne rim. Shell-driven —
/// the single source of truth for primary navigation.
class EverloreNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  const EverloreNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
  });

  // Visual order; the null gap is the center Create action.
  static const List<_Slot?> _slots = [
    _Slot(AppIcons.navExplore, 'Explore', 0),
    _Slot(AppIcons.navRealms, 'Realms', 1),
    null,
    _Slot(AppIcons.navWorlds, 'Worlds', 2),
    _Slot(AppIcons.createCharacter, 'Personas', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, bottom: bottomInset + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              // translucent forged glass
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void3.withValues(alpha: 0.72),
                  EverloreTheme.void1.withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (final slot in _slots)
                    slot == null
                        ? _CreateAction(onTap: onCreate)
                        : Expanded(
                            child: _NavTab(
                              slot: slot,
                              active: currentIndex == slot.branch,
                              onTap: () => onSelect(slot.branch),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final _Slot slot;
  final bool active;
  final VoidCallback onTap;
  const _NavTab({
    required this.slot,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? EverloreTheme.gold : EverloreTheme.ash;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    EverloreTheme.gold.withValues(alpha: 0.18),
                    EverloreTheme.gold.withValues(alpha: 0.05),
                  ],
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: active ? 1 : 0.62,
              child: EvIcon(slot.icon, size: 22),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                slot.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: color,
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised forged-brass center action — a skeuomorphic minted disc.
class _CreateAction extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [
              EverloreTheme.goldGlow,
              EverloreTheme.gold,
              EverloreTheme.goldDeep,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: EverloreTheme.goldHot.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: EverloreTheme.gold.withValues(alpha: 0.3),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: EverloreTheme.void0, size: 30),
      ),
    );
  }
}

/// Bottom sheet to choose what to forge — a World or a Character. Resolves the
/// old "+ only made characters" gap.
void showCreateChooser(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x33D8B878))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              _CreateChoice(
                icon: AppIcons.navRealms,
                title: 'Forge a World',
                subtitle: 'A living realm others can step into and play.',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/my-worlds/forge');
                },
              ),
              const SizedBox(height: 12),
              _CreateChoice(
                icon: AppIcons.createCharacter,
                title: 'Create a Character',
                subtitle: 'A sentient companion to talk and adventure with.',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/characters/new');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreateChoice extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CreateChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [EverloreTheme.void3, EverloreTheme.void2],
          ),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    EverloreTheme.gold.withValues(alpha: 0.22),
                    EverloreTheme.void2,
                  ],
                ),
                border: Border.all(
                  color: EverloreTheme.gold.withValues(alpha: 0.4),
                ),
              ),
              child: EvIcon(icon, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: EverloreTheme.uiFamily,
                      color: EverloreTheme.ash,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: EverloreTheme.ash, size: 18),
          ],
        ),
      ),
    );
  }
}
