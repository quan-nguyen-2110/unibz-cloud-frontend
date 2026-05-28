import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_loading.dart';
import 'auth_token_store.dart';
import 'session_expired_handler.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// HTTP client for SquadUp API (JWT or dev header).
class ApiClient {
  ApiClient({http.Client? client, AuthTokenStore? tokens})
      : _client = client ?? http.Client(),
        _tokens = tokens ?? authTokenStore;

  final http.Client _client;
  final AuthTokenStore _tokens;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{
      'X-Correlation-Id': 'flutter-${DateTime.now().microsecondsSinceEpoch}',
      'Accept': 'application/json',
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    final token = _tokens.accessToken;
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    } else if (AppConfig.useDevAuth) {
      h['X-Dev-User-Id'] = AppConfig.devUserId;
    }
    return h;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool silent = false,
  }) async {
    return _withLoading(
      () async {
        final res = await _client.get(_uri(path, query), headers: _headers());
        return _decode(res, path);
      },
      silent: silent,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool silent = false,
  }) async {
    return _withLoading(
      () async {
        final res = await _client.post(
          _uri(path),
          headers: _headers(jsonBody: body != null),
          body: body != null ? jsonEncode(body) : null,
        );
        return _decode(res, path);
      },
      silent: silent,
    );
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    bool silent = false,
  }) async {
    return _withLoading(
      () async {
        final res = await _client.put(
          _uri(path),
          headers: _headers(jsonBody: body != null),
          body: body != null ? jsonEncode(body) : null,
        );
        return _decode(res, path);
      },
      silent: silent,
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    bool silent = false,
  }) async {
    return _withLoading(
      () async {
        final res = await _client.patch(
          _uri(path),
          headers: _headers(jsonBody: body != null),
          body: body != null ? jsonEncode(body) : null,
        );
        return _decode(res, path);
      },
      silent: silent,
    );
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool silent = false,
  }) async {
    return _withLoading(
      () async {
        final res = await _client.delete(_uri(path), headers: _headers());
        return _decode(res, path);
      },
      silent: silent,
    );
  }

  Future<T> _withLoading<T>(
    Future<T> Function() action, {
    required bool silent,
  }) async {
    if (silent) return action();
    ApiLoading.instance.begin();
    try {
      return await action();
    } finally {
      ApiLoading.instance.end();
    }
  }

  Map<String, dynamic> _decode(http.Response res, String path) {
    Map<String, dynamic>? parsed;
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) parsed = decoded;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parsed ?? {};
    }
    if (res.statusCode == 401 && !_isUnauthenticatedAuthPath(path)) {
      SessionExpiredHandler.instance.onUnauthorized();
    }
    final msg = _errorMessage(parsed, res.body, res.statusCode);
    throw ApiException(res.statusCode, msg);
  }

  /// Login/signup 401s are shown on those screens — do not force logout.
  static bool _isUnauthenticatedAuthPath(String path) {
    const publicAuth = {
      '/auth/login',
      '/auth/register',
      '/auth/confirm',
      '/auth/resend-code',
      '/auth/forgot-password',
      '/auth/reset-password',
    };
    return publicAuth.contains(path);
  }

  static String _errorMessage(
    Map<String, dynamic>? parsed,
    String body,
    int statusCode,
  ) {
    final err = parsed?['error'];
    if (err != null) return err.toString();
    final errors = parsed?['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        final path = first['path']?.toString();
        final msg = first['msg']?.toString();
        if (path != null && msg != null) return '$path: $msg';
        if (msg != null) return msg;
      }
    }
    if (body.isNotEmpty) return body;
    return 'HTTP $statusCode';
  }

  Future<bool> checkHealth() async {
    try {
      final data = await getJson('/healthz');
      return data['status'] == 'ok';
    } on ApiException {
      return false;
    }
  }
}
