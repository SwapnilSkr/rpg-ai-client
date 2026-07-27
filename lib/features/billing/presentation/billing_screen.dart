import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_session_loader.dart';
import '../data/billing_repository.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  BillingWallet? _wallet;
  List<ProductDetails> _products = const [];
  String? _error;
  bool _loading = true;
  StreamSubscription<BillingWallet>? _walletSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _walletSub = BillingRepository.instance.walletChanges.listen((wallet) {
      if (mounted) setState(() => _wallet = wallet);
    });
    _errorSub = BillingRepository.instance.errors.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
    _load();
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await BillingRepository.instance.wallet();
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not open memberships right now.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: EverloreTheme.parchment,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Membership & Ink',
          style: EverloreTheme.ui(
            size: 17,
            color: EverloreTheme.parchment,
            weight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: EverloreSessionLoader(message: 'Opening the ledger'),
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
          : ListView(
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
                if (!_wallet!.purchasesEnabled) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Google Play billing will appear here once this release is connected to the verified Play product catalog.',
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.ash,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _plan(String id, String title, String description, Color accent) {
    final product = _products.where((item) => item.id == id).firstOrNull;
    return _PurchaseCard(
      title: title,
      description: description,
      price: product?.price,
      accent: accent,
      enabled: product != null,
      onTap: product == null
          ? null
          : () => BillingRepository.instance.buy(product),
    );
  }

  Widget _pack(String id, String title) {
    final product = _products.where((item) => item.id == id).firstOrNull;
    return _PurchaseCard(
      title: title,
      description: 'A one-time Story Ink refill.',
      price: product?.price,
      accent: EverloreTheme.goldDim,
      enabled: product != null,
      compact: true,
      onTap: product == null
          ? null
          : () => BillingRepository.instance.buy(product),
    );
  }
}

class _InkBalance extends StatelessWidget {
  final BillingWallet wallet;
  const _InkBalance({required this.wallet});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: EverloreTheme.void2,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${wallet.balance} Ink',
          style: EverloreTheme.serifDisplay(
            size: 30,
            color: EverloreTheme.parchment,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${wallet.tier.toUpperCase()} · Standard turns cost 1 Ink. Failed generations never consume it.',
          style: EverloreTheme.ui(
            size: 12,
            color: EverloreTheme.ash,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _PurchaseCard extends StatelessWidget {
  final String title, description;
  final String? price;
  final Color accent;
  final bool enabled, compact;
  final VoidCallback? onTap;
  const _PurchaseCard({
    required this.title,
    required this.description,
    required this.price,
    required this.accent,
    required this.enabled,
    required this.onTap,
    this.compact = false,
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
            color: EverloreTheme.void2,
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
              Text(
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
