import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../models/purchase_product.dart';

enum PurchaseOutcome { success, cancelled, pending, error, restored }

class PurchaseResult {
  final String productId;
  final PurchaseOutcome outcome;
  final String? errorMessage;

  const PurchaseResult({
    required this.productId,
    required this.outcome,
    this.errorMessage,
  });
}

/// A completed store transaction waiting for the EliteMeet server to verify
/// it. Handed to the website (which holds the user's session) as the
/// `elitemeetPurchaseVerify` event; the website calls back
/// `finishPurchase({key, ok})` once the server has decided.
class PendingVerification {
  final String key;
  final PurchaseDetails purchase;
  final bool restored;

  const PendingVerification({
    required this.key,
    required this.purchase,
    required this.restored,
  });

  Map<String, Object?> toJson() => {
        'key': key,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'productId': purchase.productID,
        // Android: Play purchase token. iOS: StoreKit transaction id.
        'purchaseToken':
            Platform.isAndroid ? purchase.verificationData.serverVerificationData : null,
        'transactionId': Platform.isIOS ? purchase.purchaseID : null,
        'restored': restored,
      };
}

/// Owns the platform billing plugin (Google Play Billing / StoreKit via
/// `in_app_purchase`), product queries, the purchase stream, and restore.
///
/// Entitlement is never granted here. A successful store transaction is
/// queued in [pending] and emitted on [verificationRequests]; the website
/// sends it to the EliteMeet server, which verifies it with Google/Apple and
/// grants access. Only then is the transaction finished
/// ([finishPurchase]) — so if anything fails in between, Google auto-refunds
/// an unacknowledged purchase and StoreKit re-delivers an unfinished one.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Non-success outcomes (cancelled / pending / error) for the
  /// `elitemeetPurchaseComplete` event.
  final ValueNotifier<PurchaseResult?> lastResult = ValueNotifier<PurchaseResult?>(null);

  final StreamController<PendingVerification> _verificationRequests =
      StreamController<PendingVerification>.broadcast();
  Stream<PendingVerification> get verificationRequests => _verificationRequests.stream;

  /// Transactions awaiting server verification, keyed by purchase token (Android)
  /// or transaction id (iOS).
  final Map<String, PendingVerification> _pending = {};
  List<PendingVerification> get pending => _pending.values.toList(growable: false);

  final Map<String, ProductDetails> _products = {};
  bool _available = false;

  /// While true, restored purchases the store already considers finished are
  /// ignored (startup recovery only cares about unfinished ones).
  bool _silentRestore = false;

  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[PurchaseService] Store billing unavailable on this device.');
      return;
    }

    if (Platform.isIOS) {
      final iosPlatformAddition =
          _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(_PaymentQueueDelegate());
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('[PurchaseService] purchaseStream error: $error'),
    );

    await _loadProducts(ProductCatalog.allProductIds);

    // Android: recover purchases that were paid but never acknowledged /
    // consumed (app killed mid-flow, pending payment that cleared later).
    // iOS re-delivers unfinished transactions on its own.
    if (Platform.isAndroid) {
      _silentRestore = true;
      await _iap.restorePurchases();
      // Restored results arrive asynchronously on the purchase stream.
      Future<void>.delayed(const Duration(seconds: 10), () => _silentRestore = false);
    }
  }

  bool get isAvailable => _available;

  ProductDetails? productDetails(String productId) => _products[productId];

  Future<void> _loadProducts(Set<String> ids) async {
    final missing = ids.where((id) => !_products.containsKey(id)).toSet();
    if (missing.isEmpty) return;
    final response = await _iap.queryProductDetails(missing);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[PurchaseService] Product IDs not found in store console '
          '(check spelling/activation status): ${response.notFoundIDs}');
    }
    for (final p in response.productDetails) {
      // A Play subscription comes back once per base plan/offer. Use the base
      // plan (no offerId) so the price shown matches what's charged.
      if (p is GooglePlayProductDetails && _products.containsKey(p.id)) {
        final offers = p.productDetails.subscriptionOfferDetails;
        final idx = p.subscriptionIndex;
        if (offers != null && idx != null && offers[idx].offerId != null) continue;
      }
      _products[p.id] = p;
    }
  }

  /// Localized prices for the website to display (store policy: the price
  /// shown must be the price charged).
  Future<List<Map<String, String>>> getProducts(List<String> productIds) async {
    if (!_available) return const [];
    await _loadProducts(productIds.toSet());
    return [
      for (final id in productIds)
        if (_products[id] != null)
          {
            'id': id,
            'price': _products[id]!.price,
            'title': _products[id]!.title,
            'currencyCode': _products[id]!.currencyCode,
          },
    ];
  }

  /// Starts a purchase for [productId]. [accountId] is the EliteMeet user id;
  /// it's attached to the store transaction (Play obfuscatedAccountId /
  /// StoreKit appAccountToken) so the server can reject a receipt replayed
  /// from another account. The outcome arrives asynchronously.
  Future<void> purchase(String productId, {String? accountId, bool? subscription}) async {
    void fail(String message) => lastResult.value = PurchaseResult(
          productId: productId,
          outcome: PurchaseOutcome.error,
          errorMessage: message,
        );

    if (!_available) return fail('Store billing unavailable');

    await _loadProducts({productId});
    final product = _products[productId];
    if (product == null) return fail('Unknown product ID: $productId');

    final isSubscription = subscription ?? ProductCatalog.isSubscriptionId(productId);
    final account = (accountId != null && accountId.isNotEmpty) ? accountId : null;

    try {
      if (Platform.isAndroid) {
        final param = GooglePlayPurchaseParam(
          productDetails: product,
          applicationUserName: account,
          changeSubscriptionParam:
              isSubscription ? await _existingSubscriptionChange(productId) : null,
        );
        if (isSubscription) {
          await _iap.buyNonConsumable(purchaseParam: param);
        } else {
          // Consumed only after the server grants it (see finishPurchase).
          await _iap.buyConsumable(purchaseParam: param, autoConsume: false);
        }
      } else {
        final param = PurchaseParam(productDetails: product, applicationUserName: account);
        if (isSubscription) {
          await _iap.buyNonConsumable(purchaseParam: param);
        } else {
          await _iap.buyConsumable(purchaseParam: param);
        }
      }
    } catch (e) {
      fail('Could not start purchase: $e');
    }
  }

  /// Play treats each plan as a separate subscription product, so switching
  /// Plus → Gold must replace the old one or the user would pay for both.
  /// (StoreKit handles this itself within a subscription group.)
  Future<ChangeSubscriptionParam?> _existingSubscriptionChange(String newProductId) async {
    final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final past = await addition.queryPastPurchases();
    for (final p in past.pastPurchases) {
      if (p.productID != newProductId &&
          ProductCatalog.isSubscriptionId(p.productID) &&
          p.status == PurchaseStatus.purchased) {
        return ChangeSubscriptionParam(
          oldPurchaseDetails: p,
          replacementMode: ReplacementMode.withTimeProration,
        );
      }
    }
    return null;
  }

  /// User-visible restore action (required by App Store review). iOS re-runs
  /// StoreKit restore; Android re-queries owned Play purchases. Everything
  /// found goes back through server verification.
  Future<void> restorePurchases() async {
    if (!_available) return;
    _silentRestore = false;
    await _iap.restorePurchases();
  }

  /// Called by the website after the server decided on a pending purchase.
  /// [ok] = granted → acknowledge/consume/finish it. Not ok (server rejected
  /// it, e.g. another account's receipt) → iOS finishes it so it stops
  /// re-delivering; Android leaves it unacknowledged so Google refunds it.
  Future<void> finishPurchase(String key, {required bool ok}) async {
    final item = _pending.remove(key);
    if (item == null) return;
    final purchase = item.purchase;

    if (Platform.isAndroid) {
      if (!ok) return;
      if (ProductCatalog.isSubscriptionId(purchase.productID)) {
        if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
      } else {
        // Consuming also acknowledges, and lets the user buy it again.
        final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await addition.consumePurchase(purchase);
      }
      return;
    }

    if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          lastResult.value = PurchaseResult(
            productId: purchase.productID,
            outcome: PurchaseOutcome.pending,
          );
          break;

        case PurchaseStatus.error:
          lastResult.value = PurchaseResult(
            productId: purchase.productID,
            outcome: PurchaseOutcome.error,
            errorMessage: purchase.error?.message,
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          lastResult.value = PurchaseResult(
            productId: purchase.productID,
            outcome: PurchaseOutcome.cancelled,
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final restored = purchase.status == PurchaseStatus.restored;
          if (restored && _silentRestore && !purchase.pendingCompletePurchase) break;
          _queueForVerification(purchase, restored: restored);
          break;
      }
    }
  }

  void _queueForVerification(PurchaseDetails purchase, {required bool restored}) {
    final key = Platform.isAndroid
        ? purchase.verificationData.serverVerificationData
        : (purchase.purchaseID ?? purchase.verificationData.serverVerificationData);
    if (key.isEmpty) return;
    final item = PendingVerification(key: key, purchase: purchase, restored: restored);
    _pending[key] = item;
    _verificationRequests.add(item);
  }

  void dispose() {
    _subscription?.cancel();
    _verificationRequests.close();
  }
}

/// Required by StoreKit on iOS to allow the app to continue transactions
/// that started outside the app UI (e.g. Ask to Buy approvals).
class _PaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) =>
      true;

  @override
  bool shouldShowPriceConsent() => false;
}
