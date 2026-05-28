import 'package:flutter/foundation.dart';

/// Tracks in-flight HTTP calls from [ApiClient] for a global loading overlay.
class ApiLoading extends ChangeNotifier {
  ApiLoading._();

  static final ApiLoading instance = ApiLoading._();

  int _pending = 0;
  int _suppressDepth = 0;

  bool get isLoading => _pending > 0 && _suppressDepth == 0;

  void begin() {
    _pending++;
    notifyListeners();
  }

  void end() {
    if (_pending > 0) _pending--;
    notifyListeners();
  }

  /// Hides the global overlay for nested work (background sync, prefetch, etc.).
  static Future<T> runSilently<T>(Future<T> Function() action) async {
    final loading = instance;
    loading._suppressDepth++;
    loading.notifyListeners();
    try {
      return await action();
    } finally {
      loading._suppressDepth--;
      loading.notifyListeners();
    }
  }
}
