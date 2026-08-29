import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/nexus_theme.dart';
import '../../features/billing/data/billing_repository.dart';
import 'ink_mark.dart';

class EverloreTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showProfile;
  final double backgroundOpacity;

  const EverloreTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showProfile = true,
    this.backgroundOpacity = 0.98,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 14, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: backgroundOpacity),
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
      // Two weights only: the page name, and the controls. The wordmark used
      // to sit above every title, which made the left side three stacked lines
      // saying the same thing the tab bar already says, and pushed the title
      // down to the size of a label. The app is named on its icon, its splash
      // and its sign-in; it does not need to introduce itself on every tab.
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverloreTheme.ui(
                    size: 21,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                  ),
                ],
              ],
            ),
          ),
          // Reading order, and only one thing at a time: the balance is a
          // readout and carries no chrome, then a clear gap, then the round
          // controls. Giving all three the same bordered treatment is what
          // made the corner read as a clump rather than as one number and two
          // buttons.
          const SizedBox(width: 12),
          const EverloreInkBalanceChip(),
          const SizedBox(width: 14),
          for (final action in actions) ...[action, const SizedBox(width: 8)],
          if (showProfile)
            EverloreTopBarIcon(
              icon: Icons.person_outline_rounded,
              tooltip: 'Profile',
              onTap: () => context.push('/profile'),
            ),
        ],
      ),
    );
  }
}

/// Short form for the top bar, which has room for four glyphs and no more.
///
/// A granted reserve runs to eight digits, and printing it in full would eat
/// the space the page title needs.
@visibleForTesting
String compactInk(int? balance) {
  if (balance == null) return '\u2014';
  final value = balance.abs();
  if (value < 10000) return '$balance';
  if (value < 1000000) return '${(balance / 1000).toStringAsFixed(0)}K';
  final millions = balance / 1000000;
  return millions.abs() < 10
      ? '${millions.toStringAsFixed(1)}M'
      : '${millions.toStringAsFixed(0)}M';
}

/// Compact, live Story Ink balance shown on every authenticated top bar.
/// The repository broadcasts ledger changes after turns and purchases, while
/// resume/open refreshes cover grants made from another device or admin panel.
class EverloreInkBalanceChip extends StatefulWidget {
  const EverloreInkBalanceChip({super.key});

  @override
  State<EverloreInkBalanceChip> createState() => _InkBalanceChipState();
}

class _InkBalanceChipState extends State<EverloreInkBalanceChip>
    with WidgetsBindingObserver {
  BillingWallet? _wallet;
  StreamSubscription<BillingWallet>? _walletSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _walletSub = BillingRepository.instance.walletChanges.listen((wallet) {
      if (mounted) setState(() => _wallet = wallet);
    });
    _loadWallet(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWallet(forceRefresh: true);
    }
  }

  Future<void> _loadWallet({required bool forceRefresh}) async {
    try {
      final wallet = await BillingRepository.instance.wallet(
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _wallet = wallet);
    } catch (_) {
      // Keep the last known balance visible; the next resume retries.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _wallet?.balance;
    return Semantics(
      button: true,
      label: balance == null ? 'Story Ink balance' : '$balance Story Ink',
      child: Tooltip(
        message: 'Story Ink · open Membership',
        child: GestureDetector(
          onTap: () => context.push('/membership'),
          behavior: HitTestBehavior.opaque,
          // A number, not a button. It carries no fill and no border: three
          // bordered objects in a row is what made this corner read as a
          // clump, and of the three this is the one you look at rather than
          // press. The 40pt height is hit area only, so it still answers a
          // thumb aimed anywhere near it.
          //
          // The real mark, not a stand-in. It is one 256px source with no @2x
          // or @3x, which is still four times the pixels this needs — what
          // used to make it look like mud was being 22pt inside a bordered
          // pill wedged against two other bordered controls, not the asset.
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/ink-logo.png',
                  width: 24,
                  height: 24,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) =>
                      const InkMark(size: 19, color: EverloreTheme.gold),
                ),
                const SizedBox(width: 5),
                if (_loading && balance == null)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: EverloreTheme.goldDim,
                    ),
                  )
                else
                  Text(
                    compactInk(balance),
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w700,
                    ).copyWith(
                      // Tabular figures so the number does not twitch as a
                      // turn spends the balance down.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
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
