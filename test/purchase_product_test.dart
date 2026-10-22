import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/models/purchase_product.dart';

void main() {
  group('ProductCatalog', () {
    test('contains every expected product ID, spelled exactly', () {
      // Must match Play Console / App Store Connect and the website's
      // src/lib/store-products.ts.
      expect(ProductCatalog.allProductIds, {
        'elitemeet_plus_monthly',
        'elitemeet_gold_monthly',
        'elitemeet_premium_monthly',
        'elitemeet_pro_monthly',
        'elitemeet_superlike_1',
        'elitemeet_superlike_5',
        'elitemeet_rewind_1',
        'elitemeet_rewind_5',
        'elitemeet_boost_24h',
        'elitemeet_boost_7d',
        'elitemeet_boost_30d',
        'elitemeet_message_pack',
        'elitemeet_chat_unlimited_24h',
        'elitemeet_chat_unlimited_7d',
        'elitemeet_chat_unlimited_30d',
        'elitemeet_verification_fee',
      });
    });

    test('has no duplicate product IDs', () {
      final ids = ProductCatalog.products.map((p) => p.productId).toList();
      expect(ids.length, ids.toSet().length,
          reason: 'Duplicate product ID would cause silent store lookup bugs');
    });

    test('byProductId finds a known product', () {
      final product = ProductCatalog.byProductId('elitemeet_premium_monthly');
      expect(product, isNotNull);
      expect(product!.type, SubscriptionType.monthly);
      expect(product.isSubscription, isTrue);
    });

    test('byProductId returns null for an unknown ID', () {
      expect(ProductCatalog.byProductId('not_a_real_product'), isNull);
    });

    test('consumables are not classified as subscriptions', () {
      final boost = ProductCatalog.byProductId('elitemeet_boost_24h');
      expect(boost!.isSubscription, isFalse);
      expect(ProductCatalog.isSubscriptionId('elitemeet_boost_7d'), isFalse);
    });

    test('isSubscriptionId recognises plans added later in Admin → Plans', () {
      expect(ProductCatalog.isSubscriptionId('elitemeet_platinum_monthly'), isTrue);
      expect(ProductCatalog.isSubscriptionId('elitemeet_gold_yearly'), isTrue);
      expect(ProductCatalog.isSubscriptionId('elitemeet_gold_pass'), isFalse);
    });

    test('byWebPath resolves /premium to a membership subscription', () {
      final product = ProductCatalog.byWebPath('/premium');
      expect(product, isNotNull);
      expect(product!.isSubscription, isTrue);
    });

    test('byWebPath returns null for a path with no configured product', () {
      expect(ProductCatalog.byWebPath('/some/unrelated/page'), isNull);
    });
  });
}
