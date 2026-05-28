import 'package:flutter/material.dart';

import 'auth_token_store.dart';

/// Clears session and returns to login when the API responds with 401.
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static final SessionExpiredHandler instance = SessionExpiredHandler._();

  GlobalKey<NavigatorState>? navigatorKey;
  void Function()? onLogout;
  bool Function()? hasActiveSession;

  bool _handling = false;

  bool get _sessionActive {
    if (hasActiveSession?.call() == true) return true;
    final token = authTokenStore.accessToken;
    return token != null && token.isNotEmpty;
  }

  /// Called from [ApiClient] before throwing on HTTP 401 (non-auth routes).
  void onUnauthorized() {
    if (_handling || !_sessionActive) return;
    _handling = true;
    try {
      navigatorKey?.currentState?.popUntil((route) => route.isFirst);
      onLogout?.call();
      final ctx = navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
      }
    } finally {
      _handling = false;
    }
  }
}
