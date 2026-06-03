import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/nexus_theme.dart';

/// A nav destination. [isCreate] renders the raised forged center action.
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isCreate;
  const _NavItem(this.icon, this.label, this.route, {this.isCreate = false});
}

/// The app's primary bottom navigation — a raised forged-metal bar (dark
/// neumorphism: top-left light edge + deep bottom shadow) with a prominent
/// champagne "Create" action in the middle. Self-contained: taps `context.go`
/// to each destination; the [activeRoute] lights up.
class EverloreNavBar extends StatelessWidget {
  final String activeRoute;
  const EverloreNavBar({super.key, required this.activeRoute});

  static const List<_NavItem> _items = [
    _NavItem(Icons.explore_outlined, 'Explore', '/discover'),
    _NavItem(Icons.auto_stories_outlined, 'Realms', '/'),
    _NavItem(Icons.add, 'Create', '/characters/new', isCreate: true),
    _NavItem(Icons.dashboard_outlined, 'Worlds', '/my-worlds'),
    _NavItem(Icons.person_outline, 'You', '/auth'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EverloreTheme.void3, EverloreTheme.void1],
        ),
        border: Border(
          top: BorderSide(color: Color(0x22D8B878)), // faint forged edge
        ),
        boxShadow: [
          BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in _items)
                item.isCreate
                    ? _CreateAction(onTap: () => _go(context, item))
                    : _NavTab(
                        item: item,
                        active: activeRoute == item.route,
                        onTap: () => _go(context, item),
                      ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, _NavItem item) {
    if (item.route == activeRoute) return;
    context.go(item.route);
  }
}

class _NavTab extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavTab({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? EverloreTheme.gold : EverloreTheme.ash;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // Active tab sits in a softly-lit recessed cradle.
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    EverloreTheme.gold.withValues(alpha: 0.16),
                    EverloreTheme.gold.withValues(alpha: 0.05),
                  ],
                )
              : null,
          border: active
              ? Border.all(color: EverloreTheme.gold.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: EverloreTheme.uiFamily,
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [EverloreTheme.goldGlow, EverloreTheme.gold, EverloreTheme.goldDeep],
            stops: [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: EverloreTheme.goldHot.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: EverloreTheme.gold.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: EverloreTheme.void0, size: 26),
      ),
    );
  }
}
