import 'package:flutter_timezone/flutter_timezone.dart';

/// Device IANA timezone (e.g. `Europe/Rome`) for voice plan parsing.
class DeviceTimezone {
  DeviceTimezone._();

  static String? _cached;

  static Future<String?> ianaId() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached;
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      final id = tz.trim();
      if (id.isEmpty) return null;
      _cached = id;
      return id;
    } catch (_) {
      return null;
    }
  }
}
