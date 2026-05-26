import '../models/api_json.dart';
import '../models/models.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<SquadNotification>> fetch({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final data = await _client.getJson(
      '/notifications',
      query: {
        if (unreadOnly) 'unreadOnly': 'true',
        'limit': '$limit',
      },
    );
    final list = data['notifications'] as List<dynamic>? ?? [];
    return list
        .map((e) => squadNotificationFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final data = await _client.getJson('/notifications', query: {'limit': '1'});
    return data['unreadCount'] as int? ?? 0;
  }

  Future<SquadNotification?> markRead(String notificationId) async {
    final data = await _client.patchJson('/notifications/$notificationId/read');
    final n = data['notification'];
    if (n == null) return null;
    return squadNotificationFromJson(n as Map<String, dynamic>);
  }

  Future<void> markAllRead() async {
    await _client.postJson('/notifications/read-all');
  }
}
