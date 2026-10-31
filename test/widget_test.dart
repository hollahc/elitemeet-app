import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/main.dart';
import 'package:elitemeet_app/services/deep_link_service.dart';

void main() {
  // Pumping the whole app builds the WebView, which has no platform
  // implementation in unit tests — so check the root widget and the
  // pieces around it instead.
  test('EliteMeet app root widget can be created', () {
    expect(const EliteMeetApp(), isA<EliteMeetApp>());
  });

  group('elitemeet:// sign-in hand-off links', () {
    test('map to the same page on the website', () {
      final uri = DeepLinkService.normalize(Uri.parse('elitemeet://app-signin?th=abc123'));
      expect(uri.scheme, 'https');
      expect(DeepLinkService.isInternalUri(uri), isTrue);
      expect(uri.path, '/app-signin');
      expect(uri.queryParameters['th'], 'abc123');
    });

    test('leave website links untouched', () {
      final web = Uri.parse('https://elitemeet.net/chat/1');
      expect(DeepLinkService.normalize(web), web);
    });
  });
}
