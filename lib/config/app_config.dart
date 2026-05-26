/// Runtime configuration via `--dart-define` (Flutter Web / mobile).
///
/// **AWS (ECS + Cognito):** run `scripts/run_aws.ps1` or:
/// `flutter run --dart-define=API_BASE_URL=http://<alb-dns> --dart-define=USE_DEV_AUTH=false`
///
/// **Local Node + AWS:** `scripts/run_local_backend.ps1` + `squadUp-backend/scripts/run-local-aws.ps1`
/// (Cognito login, same DynamoDB/S3 as cloud; API at `127.0.0.1:8080` on Android emulator via adb reverse).
///
/// **Local Docker (in-memory):** `scripts/start_backend.ps1` + `scripts/run_local.ps1`
/// (`USE_DEV_AUTH=true`, no Cognito).
class AppConfig {
  AppConfig._();

  static const String defaultLocalApiBaseUrl = 'http://10.0.2.2:8080';

  static const String defaultAwsApiBaseUrl =
      'http://squadup-alb-363579702.us-east-1.elb.amazonaws.com';

  /// Default dev user when using local Docker (`devUserStore.js`).
  static const String defaultDevUserId = '00000000-0000-4000-a000-000000000001';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultLocalApiBaseUrl,
  );

  /// Local Docker only — sends `X-Dev-User-Id` instead of Cognito JWT.
  static const String devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: defaultDevUserId,
  );

  static const bool useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: false,
  );
}
