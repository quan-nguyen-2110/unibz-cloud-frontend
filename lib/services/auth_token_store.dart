import 'package:flutter/foundation.dart';

/// Holds Cognito access token for API calls (Week 1: optional + dev header fallback).
class AuthTokenStore extends ChangeNotifier {
  String? _accessToken;

  String? get accessToken => _accessToken;

  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  void setAccessToken(String? token) {
    _accessToken = token;
    notifyListeners();
  }

  void clear() {
    _accessToken = null;
    notifyListeners();
  }
}

final authTokenStore = AuthTokenStore();
