/// Runtime configuration via `--dart-define` (Flutter Web / mobile).
///
/// **AWS (ECS + Cognito):** run `scripts/run_aws.ps1` or:
/// `flutter run --dart-define=API_BASE_URL=http://<alb-dns> --dart-define=USE_API=true --dart-define=USE_DEV_AUTH=false`
///
/// **Local Docker:** add `USE_DEV_AUTH=true` and `API_BASE_URL=http://localhost:8080`
/// (Android emulator: `http://10.0.2.2:8080`).
class AppConfig {
  AppConfig._();

  /// Deployed ALB from `terraform output api_base_url` (override with `--dart-define`).
  static const String defaultAwsApiBaseUrl =
      'http://squadup-alb-363579702.us-east-1.elb.amazonaws.com';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultAwsApiBaseUrl,
  );

  /// When true, feed/login use the HTTP API instead of in-memory mocks.
  static const bool useApi = bool.fromEnvironment('USE_API', defaultValue: true);

  /// Development auth bypass (local Docker only — `X-Dev-User-Id`).
  static const String devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: 'u_ali',
  );

  static const bool useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: false,
  );
}
