import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/config/environment.dart';
import 'package:elitemeet_app/config/app_config.dart';

void main() {
  group('Environment', () {
    test('defaults to production when no --dart-define is passed', () {
      // This test runs without ELITEMEET_ENV defined, so it exercises the
      // documented default. To verify the dev/staging branches, run:
      //   flutter test --dart-define=ELITEMEET_ENV=staging
      expect(Environment.current, AppEnvironment.production);
      expect(Environment.isProduction, isTrue);
      expect(Environment.label, 'PRODUCTION');
    });

    test('production base URL is the real elitemeet.net domain', () {
      expect(Environment.baseUrl, 'https://elitemeet.net');
    });
  });

  group('AppConfig', () {
    test('websiteUrl matches the Environment-resolved base URL', () {
      expect(AppConfig.websiteUrl, Environment.baseUrl);
    });

    test('internalHost is derived correctly from websiteUrl', () {
      expect(AppConfig.internalHost, 'elitemeet.net');
    });

    test('applicationId matches the confirmed final value', () {
      expect(AppConfig.applicationId, 'net.elitemeet.app');
    });

    test('user agent suffix identifies the app for website detection', () {
      expect(AppConfig.userAgentSuffix, contains('EliteMeetApp'));
    });
  });
}
