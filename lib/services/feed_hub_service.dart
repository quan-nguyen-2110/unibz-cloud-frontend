import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/api_json.dart';
import '../models/models.dart';
import 'auth_token_store.dart';

/// Minimal SignalR JSON client for SquadUp `/hub/feed`.
class FeedHubService {
  static const _rs = '\u001e';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _shouldRun = false;
  void Function(PlanCancelledHubEvent event)? onPlanCancelled;
  void Function(InboxNotificationHubEvent event)? onInboxNotification;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    _shouldRun = true;
    await _open();
  }

  Future<void> disconnect() async {
    _shouldRun = false;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _open() async {
    if (!_shouldRun) return;

    final uri = AppConfig.feedHubUri(
      accessToken: authTokenStore.accessToken,
      devUserId: AppConfig.useDevAuth ? AppConfig.devUserId : null,
    );

    await _sub?.cancel();
    await _channel?.sink.close();

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.sink.add('${jsonEncode({
            'protocol': 'json',
            'version': 1,
          })}$_rs');

      _sub = _channel!.stream.listen(
        _onFrame,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldRun) return;
    _channel = null;
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_shouldRun) _open();
    });
  }

  void _onFrame(dynamic data) {
    final text = data.toString();
    for (final part in text.split(_rs)) {
      if (part.trim().isEmpty) continue;
      Map<String, dynamic>? msg;
      try {
        final decoded = jsonDecode(part);
        if (decoded is Map<String, dynamic>) msg = decoded;
      } catch (_) {
        continue;
      }
      if (msg == null) continue;

      final type = msg['type'];
      if (type == 6) {
        _channel?.sink.add('${jsonEncode({'type': 6})}$_rs');
        continue;
      }
      if (type != 1) continue;

      final target = msg['target'] as String?;
      final args = msg['arguments'];
      if (args is! List || args.isEmpty) continue;
      final payload = args.first;
      if (payload is! Map) continue;
      final map = Map<String, dynamic>.from(payload);

      if (target == 'planCancelled') {
        final event = planCancelledHubEventFromJson(map);
        if (event.planId.isEmpty) continue;
        onPlanCancelled?.call(event);
        onInboxNotification?.call(event.toInboxEvent());
        continue;
      }

      const inboxTargets = {
        'newAttendee': 'new_attendee',
        'attendeeLeft': 'attendee_left',
      };
      final inboxType = inboxTargets[target];
      if (inboxType == null) continue;

      final event = inboxNotificationHubEventFromJson(inboxType, json: map);
      onInboxNotification?.call(event);
    }
  }
}
