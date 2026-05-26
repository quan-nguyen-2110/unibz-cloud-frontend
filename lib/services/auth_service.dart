import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
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
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      throw AuthException('Enter your email and password.');
    }

    try {
      final data = await _client.postJson(
        '/auth/login',
        body: {'email': trimmedEmail, 'password': trimmedPassword},
      );
      final token = data['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Login failed — no access token returned.');
      }
      authTokenStore.setAccessToken(token);
    } on ApiException catch (e) {
      debugPrint(
        'AuthService.login ApiException: ${e.statusCode} ${e.message}',
      );
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('AuthService.login error: $e');
      final hint = AppConfig.apiBaseUrl.contains('127.0.0.1') ||
              AppConfig.apiBaseUrl.contains('10.0.2.2')
          ? ' Is the API running? Try: squadUp-backend/scripts/run-local-aws.ps1 '
            'and mobile scripts/run_local_aws.ps1 (uses adb reverse).'
          : ' Use scripts/run_aws.ps1 for AWS, or check emulator internet.';
      throw AuthException(
        'Cannot reach the API at ${AppConfig.apiBaseUrl}.$hint'
        '${kDebugMode ? ' ($e)' : ''}',
      );
    }
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

  /// Sends a password-reset code to [email] (Cognito `ForgotPassword`).
  Future<String> forgotPassword(String email) async {
    if (email.trim().isEmpty) {
      throw AuthException('Enter a valid email address.');
    }
    try {
      final data = await _client.postJson(
        '/auth/forgot-password',
        body: {'email': email.trim()},
      );
      return data['message'] as String? ??
          'If an account exists for this email, a reset code has been sent';
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException(
        'Cannot reach the API at ${AppConfig.apiBaseUrl}. '
        'Use scripts/run_aws.ps1 for AWS, or check emulator internet.',
      );
    }
  }

  /// Confirms reset code and sets a new password (Cognito `ConfirmForgotPassword`).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      await _client.postJson(
        '/auth/reset-password',
        body: {
          'email': email.trim(),
          'code': code.trim(),
          'password': password,
        },
      );
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw AuthException(
        'Cannot reach the API at ${AppConfig.apiBaseUrl}. '
        'Use scripts/run_aws.ps1 for AWS, or check emulator internet.',
      );
    }
  }

  void logout() {
    authTokenStore.clear();
  }
}
