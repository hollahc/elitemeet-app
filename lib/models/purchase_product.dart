enum SubscriptionType { monthly, yearly, consumable }

/// Describes one purchasable EliteMeet product, and (optionally) which
/// website path should trigger it if the user reaches it via ordinary
/// WebView navigation rather than the JS bridge's `purchase()` call.
///
/// Product IDs must match exactly (including case) what's configured in
/// Google Play Console and App Store Connect — see docs/BILLING.md. A
/// mismatch fails silently with a generic "product not found" error.
///
/// The website is the source of truth for which product to buy (it passes
/// the ID through `window.EliteMeetApp.purchase`), and the EliteMeet server
/// decides what each ID grants. This list is only used to pre-load store
/// prices and as the fallback for plain `/premium` links.
class PurchaseConfiguration {
  final String productId;
  final SubscriptionType type;

  /// Website path that should route to this product when encountered as a
  /// plain navigation (e.g. a `<a href="/premium">` the site didn't wire
  /// through the JS bridge). Optional — most purchases should go through
  /// `window.EliteMeetApp.purchase()` instead.
  final String? webPath;

  const PurchaseConfiguration({
    required this.productId,
    required this.type,
    this.webPath,
  });

  bool get isSubscription =>
      type == SubscriptionType.monthly || type == SubscriptionType.yearly;
}

/// The full EliteMeet product catalog. Keep product IDs identical across
/// Android and iOS, and in sync with the website's
/// `src/lib/store-products.ts`.
class ProductCatalog {
  ProductCatalog._();

  static const List<PurchaseConfiguration> products = [
    // Membership plans — auto-renewing subscriptions. Pattern:
    // elitemeet_<plan code>_monthly|yearly (plan codes from Admin → Plans).
    PurchaseConfiguration(
      productId: 'elitemeet_plus_monthly',
      type: SubscriptionType.monthly,
      webPath: '/premium',
    ),
    PurchaseConfiguration(
      productId: 'elitemeet_gold_monthly',
      type: SubscriptionType.monthly,
    ),
    PurchaseConfiguration(
      productId: 'elitemeet_premium_monthly',
      type: SubscriptionType.monthly,
    ),
    PurchaseConfiguration(
      productId: 'elitemeet_pro_monthly',
      type: SubscriptionType.monthly,
    ),

    // Consumables.
    PurchaseConfiguration(productId: 'elitemeet_superlike_1', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_superlike_5', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_rewind_1', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_rewind_5', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_boost_24h', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_boost_7d', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_boost_30d', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_message_pack', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_chat_unlimited_24h', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_chat_unlimited_7d', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_chat_unlimited_30d', type: SubscriptionType.consumable),
    PurchaseConfiguration(productId: 'elitemeet_verification_fee', type: SubscriptionType.consumable),
  ];

  static Set<String> get allProductIds =>
      products.map((p) => p.productId).toSet();

  static PurchaseConfiguration? byProductId(String id) {
    for (final p in products) {
      if (p.productId == id) return p;
    }
    return null;
  }

  /// Subscription check for IDs not in the static list (new plans created
  /// in Admin → Plans follow the `elitemeet_<code>_monthly|yearly` pattern).
  static bool isSubscriptionId(String id) {
    final known = byProductId(id);
    if (known != null) return known.isSubscription;
    return id.endsWith('_monthly') || id.endsWith('_yearly');
  }

  static PurchaseConfiguration? byWebPath(String path) {
    for (final p in products) {
      if (p.webPath != null && path.startsWith(p.webPath!)) return p;
    }
    return null;
  }
}
