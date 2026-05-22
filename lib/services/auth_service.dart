import 'api_client.dart';
import 'auth_token_store.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cognito login via SquadUp API (`POST /auth/login`).
class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> login({required String email, required String password}) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw AuthException('Enter your email and password.');
    }

    try {
      final data = await _client.postJson(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      );
      final token = data['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Login failed — no access token returned.');
      }
      authTokenStore.setAccessToken(token);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Prototype path when API/Cognito is unavailable (matches layout TODO stub).
  Future<void> loginDemo() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      await _client.postJson(
        '/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'username': username.trim(),
          'displayName': displayName.trim(),
        },
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      await _client.postJson(
        '/auth/confirm',
        body: {'email': email.trim(), 'code': code.trim()},
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Prototype path when API/Cognito is unavailable — `signup.tsx` stub.
  Future<void> signUpDemo() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> refreshToken(String refreshToken) async {
    try {
      final data = await _client.postJson(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      final token = data['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Refresh failed — no access token returned.');
      }
      authTokenStore.setAccessToken(token);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> resendConfirmationCode(String email) async {
    try {
      await _client.postJson(
        '/auth/resend-code',
        body: {'email': email.trim()},
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  void logout() {
    authTokenStore.clear();
  }
}
