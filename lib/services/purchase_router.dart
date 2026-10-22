import '../models/purchase_product.dart';
import 'purchase_service.dart';

/// Central purchase entry point.
///
/// ```text
/// EliteMeet Web
///        |
///        v
/// Purchase URL/button  --or--  window.EliteMeetApp.purchase({productId})
///        |
///        v
/// PurchaseRouter.routeProductId() / routeWebPath()
///        |
///        v
/// PurchaseService (Play Billing / StoreKit)
/// ```
///
/// Nothing else in the app should call [PurchaseService] directly — routing
/// through here keeps the "which URL/product maps to which store SKU"
/// policy in one place (Section 15/16).
class PurchaseRouter {
  PurchaseRouter._();
  static final PurchaseRouter instance = PurchaseRouter._();

  /// Called by the JS bridge when the website invokes
  /// `window.EliteMeetApp.purchase({ productId })`.
  Future<void> routeProductId(String productId, {String? accountId, bool? subscription}) async {
    await PurchaseService.instance.purchase(
      productId,
      accountId: accountId,
      subscription: subscription,
    );
  }

  /// Called when the WebView intercepts a navigation classified as a
  /// purchase route (a plain `<a href="/premium">` the site didn't wire
  /// through the JS bridge). Falls back to whatever product is configured
  /// for that path.
  Future<bool> routeWebPath(String path) async {
    final config = ProductCatalog.byWebPath(path);
    if (config == null) return false;
    await PurchaseService.instance.purchase(config.productId);
    return true;
  }
}
