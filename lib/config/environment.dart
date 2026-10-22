/// Build-time environment selection for EliteMeet.
///
/// Selected via `--dart-define=ELITEMEET_ENV=production` (or dev/staging).
/// Defaults to production if not specified, so a plain `flutter run` still
/// points at the live site.
enum AppEnvironment { dev, staging, production }

class Environment {
  static AppEnvironment get current {
    const raw = String.fromEnvironment('ELITEMEET_ENV', defaultValue: 'production');
    switch (raw) {
      case 'dev':
        return AppEnvironment.dev;
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
      default:
        return AppEnvironment.production;
    }
  }

  static String get baseUrl {
    switch (current) {
      case AppEnvironment.dev:
        return const String.fromEnvironment(
          'ELITEMEET_BASE_URL',
          defaultValue: 'https://dev.elitemeet.net',
        );
      case AppEnvironment.staging:
        return const String.fromEnvironment(
          'ELITEMEET_BASE_URL',
          defaultValue: 'https://staging.elitemeet.net',
        );
      case AppEnvironment.production:
        return const String.fromEnvironment(
          'ELITEMEET_BASE_URL',
          defaultValue: 'https://elitemeet.net',
        );
    }
  }

  static bool get isProduction => current == AppEnvironment.production;

  static String get label {
    switch (current) {
      case AppEnvironment.dev:
        return 'DEV';
      case AppEnvironment.staging:
        return 'STAGING';
      case AppEnvironment.production:
        return 'PRODUCTION';
    }
  }
}
