import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/user.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/telemetry/telemetry_vocabulary.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../../../shared/widgets/ink_mark.dart';
import '../data/billing_repository.dart';
import '../../../shared/widgets/everlore_notice.dart';

/// `paywall_shown` with where the screen was opened from (the route's
/// `source` query). A missing or unknown source is left out, not guessed.
void trackPaywallShown(String? source) {
  Telemetry.instance.track('paywall_shown', {
    if (source != null && paywallSources.contains(source)) 'source': source,
  });
}

class BillingScreen extends StatefulWidget {
  final User? user;
  final BillingWallet? wallet;

  /// Where the player came from (`ink`, `profile`, `top_bar`, ...), passed
  /// through the route so `paywall_shown` says what led here.
  final String? source;

  const BillingScreen({super.key, this.user, this.wallet, this.source});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  User? _user;
  BillingWallet? _wallet;
  List<ProductDetails> _products = const [];
  String? _error;
  bool _loading = true;
  String? _purchaseInFlight;
  StreamSubscription<BillingWallet>? _walletSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    // Once per opening of the screen, never on a rebuild.
    trackPaywallShown(widget.source);
    _user = widget.user;
    if (widget.wallet != null) {
      _wallet = widget.wallet;
      _loading = false;
    }
    _walletSub = BillingRepository.instance.walletChanges.listen((wallet) {
      if (mounted) setState(() => _wallet = wallet);
    });
    _errorSub = BillingRepository.instance.errors.listen((message) {
      if (mounted) {
        showEverloreNotice(context, message, tone: NoticeTone.error);
      }
    });
    if (widget.wallet == null || _user == null) {
      _load();
    }
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = widget.wallet == null;
      _error = null;
    });
    try {
      _user ??= await AuthService.getCachedUser() ??
          await AuthService.getCurrentUser();
      if (widget.wallet == null) {
        final wallet = await BillingRepository.instance.wallet(
          forceRefresh: true,
        );
        final products = wallet.purchasesEnabled
            ? await BillingRepository.instance.products()
            : const <ProductDetails>[];
        if (mounted) {
          setState(() {
            _wallet = wallet;
            _products = products;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not open memberships right now.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _simulatePurchase(String productId) async {
    if (_purchaseInFlight != null) return;
    setState(() => _purchaseInFlight = productId);
    try {
      final wallet = await BillingRepository.instance.simulatePurchase(
        productId,
      );
      if (mounted) {
        setState(() => _wallet = wallet);
        showEverloreNotice(
          context,
          'Test checkout complete — no charge.',
          tone: NoticeTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showEverloreNotice(
          context,
          'Test checkout could not be completed.',
          tone: NoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _purchaseInFlight = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPromo = _wallet?.unlimitedInk == true;
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Stack(
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
                colors: isPromo
                    ? [
                        EverloreTheme.void0.withValues(alpha: 0.06),
                        EverloreTheme.void0.withValues(alpha: 0.18),
                        EverloreTheme.void0.withValues(alpha: 0.68),
                        EverloreTheme.void0.withValues(alpha: 0.96),
                        EverloreTheme.void0,
                      ]
                    : [
                        EverloreTheme.void0.withValues(alpha: 0.24),
                        EverloreTheme.void0.withValues(alpha: 0.58),
                        EverloreTheme.void0.withValues(alpha: 0.8),
                      ],
                stops: isPromo
                    ? const [0, 0.34, 0.6, 0.78, 1]
                    : const [0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Membership & Ink',
                        style: EverloreTheme.ui(
                          size: 17,
                          color: EverloreTheme.parchment,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: EverloreTheme.void0.withValues(alpha: 0.7),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.pop(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.close_rounded,
                              color: EverloreTheme.parchment,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: EverloreSessionLoader(
                            message: 'Opening the ledger',
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: TextButton(
                            onPressed: _load,
                            child: Text(
                              _error!,
                              style: const TextStyle(color: EverloreTheme.gold),
                            ),
                          ),
                        )
                      : isPromo
                      ? _buildPromoBody(context, _user?.canAccessForge ?? false)
                      : _buildNormalBody(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBody(BuildContext context, bool canForge) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                _InkBalance(wallet: _wallet!),
                const SizedBox(height: 24),
                Text(
                  'WHILE THE INK FLOWS FREE',
                  style: EverloreTheme.sectionHeader,
                ),
                const SizedBox(height: 14),
                const _PromoFeatureRow(
                  icon: Icons.auto_stories_outlined,
                  title: 'Every story, without counting',
                  description: 'Write as many turns as you like.',
                ),
                if (canForge) ...[
                  const SizedBox(height: 14),
                  const _PromoFeatureRow(
                    icon: Icons.auto_fix_high_rounded,
                    title: 'Forge your own worlds',
                    description:
                        'Make worlds and characters, whatever your membership.',
                  ),
                ],
                const SizedBox(height: 14),
                const _PromoFeatureRow(
                  icon: Icons.palette_outlined,
                  title: 'Portraits and drafts, free',
                  description: 'Cover art and story drafts cost no ink.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Memberships return when the promotion ends. Everything you write now stays yours.',
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.ash,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: [
        _InkBalance(wallet: _wallet!),
        const SizedBox(height: 26),
        Text('MEMBERSHIPS', style: EverloreTheme.sectionHeader),
        const SizedBox(height: 10),
        _plan(
          'everlore_premium',
          'Premium',
          '3,000 Ink each month · generous everyday play · forge access',
          EverloreTheme.gold,
        ),
        const SizedBox(height: 12),
        _plan(
          'everlore_creator',
          'Creator',
          '6,000 Ink each month · larger forge allowance · publish worlds',
          EverloreTheme.violet,
        ),
        const SizedBox(height: 26),
        Text('ADD INK', style: EverloreTheme.sectionHeader),
        const SizedBox(height: 10),
        _pack('everlore_ink_100', 'Small refill'),
        _pack('everlore_ink_350', 'Most popular'),
        _pack('everlore_ink_900', 'Deep reserves'),
        if (_wallet!.simulationEnabled) ...[
          const SizedBox(height: 24),
          Text(
            'TEST CHECKOUT · NO CHARGE\nThis internal QA mode grants Ink through the same ledger used by normal play.',
            style: EverloreTheme.ui(
              size: 13,
              color: EverloreTheme.gold,
              height: 1.45,
            ),
          ),
        ] else if (!_wallet!.purchasesEnabled) ...[
          const SizedBox(height: 24),
          Text(
            // Player-facing: no store, no catalogue, no
            // plumbing. They only need to know it is not
            // available to them yet.
            'Ink refills are not available yet. Your '
            'balance and everything you have written stay '
            'exactly as they are.',
            style: EverloreTheme.ui(
              size: 13,
              color: EverloreTheme.ash,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }

  Widget _plan(String id, String title, String description, Color accent) {
    final product = _products.where((item) => item.id == id).firstOrNull;
    final simulated = _wallet!.simulationEnabled && product == null;
    return _PurchaseCard(
      title: title,
      description: description,
      price: product?.price ?? (simulated ? 'Test' : null),
      accent: accent,
      enabled: (product != null || simulated) && _purchaseInFlight == null,
      busy: _purchaseInFlight == id,
      onTap: product != null
          ? () => BillingRepository.instance.buy(product)
          : simulated
          ? () => _simulatePurchase(id)
          : null,
    );
  }

  Widget _pack(String id, String title) {
    final product = _products.where((item) => item.id == id).firstOrNull;
    final simulated = _wallet!.simulationEnabled && product == null;
    return _PurchaseCard(
      title: title,
      description: 'A one-time Story Ink refill.',
      price: product?.price ?? (simulated ? 'Test' : null),
      accent: EverloreTheme.goldDim,
      enabled: (product != null || simulated) && _purchaseInFlight == null,
      compact: true,
      busy: _purchaseInFlight == id,
      onTap: product != null
          ? () => BillingRepository.instance.buy(product)
          : simulated
          ? () => _simulatePurchase(id)
          : null,
    );
  }
}

/// Thousands separators, without pulling in `intl` for one label.
///
/// A granted reserve runs to eight digits, and `100000000 Ink` is a figure no
/// one can read at a glance on the one screen that exists to state it exactly.
String _grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _InkBalance extends StatelessWidget {
  final BillingWallet wallet;
  const _InkBalance({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EverloreTheme.void0.withValues(alpha: 0.56),
        borderRadius: radius,
        border: Border.all(
          color: EverloreTheme.goldDim.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR STORY INK',
                  style: EverloreTheme.ui(
                    size: 10,
                    color: EverloreTheme.gold,
                    weight: FontWeight.w700,
                    spacing: 1.7,
                  ),
                ),
                const SizedBox(height: 6),
                // The one screen whose job is the exact figure, so it is not
                // abbreviated the way the top bar's is — grouped instead, and
                // scaled down rather than clipped when a grant runs long.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    wallet.unlimitedInk
                        ? 'Unlimited Ink'
                        : '${_grouped(wallet.balance)} Ink',
                    maxLines: 1,
                    style: EverloreTheme.serifDisplay(
                      size: 30,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  wallet.unlimitedInk
                      ? 'Write as much as you like — for a limited time.'
                      : '${wallet.tier.toUpperCase()} · Standard turns cost 1 Ink. A turn that fails never spends it.',
                  style: EverloreTheme.ui(
                    size: 12,
                    color: EverloreTheme.ash,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // The mark's one home at full size. Everywhere else it is drawn flat
          // in brass because the render cannot hold together at icon scale;
          // here there is room for the real thing, over art dark enough to
          // carry it.
          Image.asset(
            'assets/icons/ink-logo.png',
            width: 78,
            height: 78,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) =>
                const InkMark(size: 64, color: EverloreTheme.gold),
          ),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final String title, description;
  final String? price;
  final Color accent;
  final bool enabled, compact, busy;
  final VoidCallback? onTap;
  const _PurchaseCard({
    required this.title,
    required this.description,
    required this.price,
    required this.accent,
    required this.enabled,
    required this.onTap,
    this.compact = false,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            color: EverloreTheme.void2.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: enabled ? 0.42 : 0.18),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: EverloreTheme.ui(
                        size: 16,
                        color: EverloreTheme.parchment,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.ash,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Text(
                      price ?? '—',
                      style: EverloreTheme.ui(
                        size: 14,
                        color: enabled ? accent : EverloreTheme.ash,
                        weight: FontWeight.w700,
                      ),
                    ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PromoFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PromoFeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EverloreTheme.void2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: EverloreTheme.gold,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: EverloreTheme.ui(
                  size: 15,
                  color: EverloreTheme.parchment,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: EverloreTheme.ui(
                  size: 13,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
