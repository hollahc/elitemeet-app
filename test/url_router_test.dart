import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/services/url_router.dart';

void main() {
  group('UrlRouter.classify', () {
    test('classifies internal elitemeet.net navigation', () {
      expect(
        UrlRouter.classify(Uri.parse('https://elitemeet.net/messages/123')),
        RouteAction.internal,
      );
    });

    test('classifies www. subdomain as internal too', () {
      expect(
        UrlRouter.classify(Uri.parse('https://www.elitemeet.net/profile')),
        RouteAction.internal,
      );
    });

    test('classifies /premium as a purchase route', () {
      expect(
        UrlRouter.classify(Uri.parse('https://elitemeet.net/premium')),
        RouteAction.purchase,
      );
    });

    test('classifies /checkout and /upgrade as purchase routes', () {
      expect(
        UrlRouter.classify(Uri.parse('https://elitemeet.net/checkout/step2')),
        RouteAction.purchase,
      );
      expect(
        UrlRouter.classify(Uri.parse('https://elitemeet.net/upgrade')),
        RouteAction.purchase,
      );
    });

    test('classifies tel: as telephone', () {
      expect(
        UrlRouter.classify(Uri.parse('tel:+15551234567')),
        RouteAction.telephone,
      );
    });

    test('classifies mailto: as email', () {
      expect(
        UrlRouter.classify(Uri.parse('mailto:support@elitemeet.net')),
        RouteAction.email,
      );
    });

    test('classifies maps.google.com as maps', () {
      expect(
        UrlRouter.classify(Uri.parse('https://maps.google.com/?q=Nairobi')),
        RouteAction.maps,
      );
    });

    test('classifies an unrelated https domain as external', () {
      expect(
        UrlRouter.classify(Uri.parse('https://instagram.com/elitemeet')),
        RouteAction.external,
      );
    });

    test('classifies an unknown custom scheme as external, not swallowed', () {
      expect(
        UrlRouter.classify(Uri.parse('someotherapp://open?id=1')),
        RouteAction.external,
      );
    });

    test('a random path on an external host is still external, not purchase', () {
      // Guards against accidentally matching purchase path prefixes on the
      // wrong host.
      expect(
        UrlRouter.classify(Uri.parse('https://evil.example.com/premium')),
        RouteAction.external,
      );
    });
  });
}
