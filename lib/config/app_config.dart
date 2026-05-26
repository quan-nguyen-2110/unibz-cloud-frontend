/// Runtime configuration via `--dart-define` (Flutter Web / mobile).
///
/// **AWS (ECS + Cognito):** run `scripts/run_aws.ps1` or:
/// `flutter run --dart-define=API_BASE_URL=http://<alb-dns> --dart-define=USE_DEV_AUTH=false`
///
/// **Local Node + AWS:** `scripts/run_local_backend.ps1` + `squadUp-backend/scripts/run-local-aws.ps1`
/// (Cognito login, same DynamoDB/S3 as cloud; API at `127.0.0.1:8080` on Android emulator via adb reverse).
///
/// **Local dev auth:** `USE_DEV_AUTH=true` sends `X-Dev-User-Id` (no Cognito login); backend still uses DynamoDB.
class AppConfig {
  AppConfig._();

  static const String defaultLocalApiBaseUrl = 'http://10.0.2.2:8080';

  static const String defaultAwsApiBaseUrl =
      'http://squadup-alb-363579702.us-east-1.elb.amazonaws.com';

  /// Default user id when `USE_DEV_AUTH=true` (must exist in DynamoDB users table).
  static const String defaultDevUserId = '00000000-0000-4000-a000-000000000001';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultLocalApiBaseUrl,
  );

  /// Local development — sends `X-Dev-User-Id` instead of Cognito JWT.
  static const String devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: defaultDevUserId,
  );

  static const bool useDevAuth = bool.fromEnvironment(
    'USE_DEV_AUTH',
    defaultValue: false,
  );

  /// WebSocket feed hub (`/hub/feed`) derived from [apiBaseUrl].
  static Uri feedHubUri({String? accessToken, String? devUserId}) {
    final httpUri = Uri.parse(apiBaseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final path = httpUri.path.endsWith('/')
        ? '${httpUri.path}hub/feed'
        : '${httpUri.path}/hub/feed';
    final base = httpUri.replace(scheme: wsScheme, path: path, query: null);

    if (useDevAuth && devUserId != null && devUserId.trim().isNotEmpty) {
      return base.replace(
        queryParameters: {'devUserId': devUserId.trim()},
      );
    }
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      return base.replace(queryParameters: {'token': token});
    }
    return base;
  }
}
