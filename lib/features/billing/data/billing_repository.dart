import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/api_client.dart';

class BillingWallet {
  final String tier;
  final int balance;
  final int monthlyInk;
  final int dailyStorySafetyCap;
  final bool purchasesEnabled;
  final bool simulationEnabled;

  const BillingWallet({
    required this.tier,
    required this.balance,
    required this.monthlyInk,
    required this.dailyStorySafetyCap,
    required this.purchasesEnabled,
    required this.simulationEnabled,
  });

  factory BillingWallet.fromJson(Map<String, dynamic> json) {
    final profile = Map<String, dynamic>.from(json['profile'] as Map? ?? {});
    return BillingWallet(
      tier: json['tier']?.toString() ?? 'free',
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      monthlyInk: (profile['monthly_ink'] as num?)?.toInt() ?? 0,
      dailyStorySafetyCap:
          (profile['daily_story_safety_cap'] as num?)?.toInt() ?? 0,
      purchasesEnabled: json['purchases_enabled'] == true,
      simulationEnabled: json['simulation_enabled'] == true,
    );
  }
}

/// Play's identifiers are an entitlement contract, never a client-side price
/// table. Prices and regional INR/USD equivalents always come from Play.
const _subscriptionIds = {'everlore_premium', 'everlore_creator'};
const _allProductIds = {
  ..._subscriptionIds,
  'everlore_ink_100',
  'everlore_ink_350',
  'everlore_ink_900',
};

class BillingRepository {
  BillingRepository._();
  static final BillingRepository instance = BillingRepository._();

  final InAppPurchase _play = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final _walletChanges = StreamController<BillingWallet>.broadcast();
  final _errors = StreamController<String>.broadcast();
  bool _started = false;
  BillingWallet? _cachedWallet;
  Future<BillingWallet>? _refreshInFlight;

  Stream<BillingWallet> get walletChanges => _walletChanges.stream;
  Stream<String> get errors => _errors.stream;

  Future<BillingWallet> wallet({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedWallet != null) return _cachedWallet!;
    return refreshWallet();
  }

  /// Pull the authoritative ledger balance and notify every header/surface.
  /// Concurrent callers share one request so multiple mounted top bars do not
  /// stampede the billing endpoint.
  Future<BillingWallet> refreshWallet() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final future = () async {
      final response = await ApiClient.get('/billing/me');
      final wallet = await _walletWithCatalog(response);
      _walletChanges.add(wallet);
      return wallet;
    }();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<void> refreshInBackground() async {
    try {
      await refreshWallet();
    } catch (_) {
      // A background refresh must never surface as an uncaught async error.
    }
  }

  Future<BillingWallet> _walletWithCatalog(dynamic response) async {
    final catalog = await ApiClient.get('/billing/catalog');
    final map = Map<String, dynamic>.from(response as Map);
    map['purchases_enabled'] = catalog['purchases_enabled'] == true;
    map['simulation_enabled'] = catalog['simulation_enabled'] == true;
    final wallet = BillingWallet.fromJson(map);
    _cachedWallet = wallet;
    return wallet;
  }

  Future<BillingWallet> simulatePurchase(String productId) async {
    final response = await ApiClient.post(
      '/billing/simulate-purchase',
      body: {
        'product_id': productId,
        'idempotency_key': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    final wallet = await _walletWithCatalog(response);
    _walletChanges.add(wallet);
    return wallet;
  }

  Future<bool> start() async {
    if (_started) return await _play.isAvailable();
    _started = true;
    _purchaseSub = _play.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) =>
          _errors.add('Google Play is unavailable: $error'),
    );
    return _play.isAvailable();
  }

  Future<List<ProductDetails>> products() async {
    if (!await start()) {
      return const [];
    }
    final result = await _play.queryProductDetails(_allProductIds);
    if (result.error != null) {
      throw ApiException(statusCode: 503, message: result.error!.message);
    }
    return result.productDetails;
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    final started = _subscriptionIds.contains(product.id)
        ? await _play.buyNonConsumable(purchaseParam: param)
        : await _play.buyConsumable(purchaseParam: param, autoConsume: false);
    if (!started) {
      throw ApiException(
        statusCode: 503,
        message: 'Google Play could not start this purchase.',
      );
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      var verifiedAndGranted = false;
      try {
        if (purchase.status == PurchaseStatus.error) {
          _errors.add(
            purchase.error?.message ??
                'Google Play could not complete the purchase.',
          );
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final kind = _subscriptionIds.contains(purchase.productID)
              ? 'subscription'
              : 'consumable';
          final response = await ApiClient.post(
            '/billing/google/verify',
            body: {
              'product_id': purchase.productID,
              'purchase_token':
                  purchase.verificationData.serverVerificationData,
              'kind': kind,
            },
          );
          _walletChanges.add(await _walletWithCatalog(response));
          verifiedAndGranted = true;
        }
      } catch (error) {
        _errors.add(
          'We could not confirm this purchase yet. It will be restored safely when you reopen Everlore.',
        );
      } finally {
        // Do not acknowledge before server-side verification. Leaving an
        // unverified purchase pending lets Play deliver it again after a
        // transient API failure, rather than losing the user's entitlement.
        if (verifiedAndGranted && purchase.pendingCompletePurchase) {
          await _play.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _started = false;
  }
}
