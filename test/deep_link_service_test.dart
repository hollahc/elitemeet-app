import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.isInternalUri', () {
    test('accepts an elitemeet.net link', () {
      expect(
        DeepLinkService.isInternalUri(Uri.parse('https://elitemeet.net/messages/1')),
        isTrue,
      );
    });

    test('accepts a www.elitemeet.net link', () {
      expect(
        DeepLinkService.isInternalUri(Uri.parse('https://www.elitemeet.net/profile')),
        isTrue,
      );
    });

    test('rejects an unrelated domain', () {
      // Guards against a misconfigured/spoofed deep link being treated as
      // internal and silently loaded into the WebView.
      expect(
        DeepLinkService.isInternalUri(Uri.parse('https://not-elitemeet.net/phish')),
        isFalse,
      );
    });

    test('rejects a lookalike subdomain', () {
      expect(
        DeepLinkService.isInternalUri(Uri.parse('https://elitemeet.net.evil.com/')),
        isFalse,
      );
    });

    test('host matching is case-insensitive', () {
      expect(
        DeepLinkService.isInternalUri(Uri.parse('https://ELITEMEET.NET/profile')),
        isTrue,
      );
    });
  });
}
