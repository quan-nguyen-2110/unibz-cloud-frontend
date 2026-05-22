import 'dart:convert';

/// Minimal JWT payload decode (no signature verify — API validates tokens).
class JwtUtil {
  JwtUtil._();

  static Map<String, dynamic>? payload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      var segment = parts[1];
      final mod = segment.length % 4;
      if (mod > 0) segment += '=' * (4 - mod);
      final json = utf8.decode(base64Url.decode(segment));
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? subject(String token) {
    final p = payload(token);
    final sub = p?['sub'];
    return sub is String ? sub : null;
  }

  static String? email(String token) {
    final p = payload(token);
    final e = p?['email'] ?? p?['username'];
    return e is String ? e : null;
  }
}
