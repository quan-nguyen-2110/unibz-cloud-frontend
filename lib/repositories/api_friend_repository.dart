import '../services/api_client.dart';

class FriendEdge {
  const FriendEdge({
    required this.userId,
    required this.friendId,
    required this.status,
  });

  final String userId;
  final String friendId;
  final String status;

  factory FriendEdge.fromJson(Map<String, dynamic> json) {
    return FriendEdge(
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class FriendListPayload {
  const FriendListPayload({required this.ids, required this.profiles});

  final List<String> ids;
  final List<Map<String, dynamic>> profiles;
}

class ApiFriendRepository {
  ApiFriendRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  List<Map<String, dynamic>> _parseProfiles(Map<String, dynamic> data) {
    final raw = data['profiles'];
    if (raw is Map) {
      return raw.values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<FriendListPayload> fetchFriends() async {
    final data = await _client.getJson('/friends');
    final list = data['friends'] as List<dynamic>? ?? [];
    return FriendListPayload(
      ids: list
          .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).friendId)
          .toList(),
      profiles: _parseProfiles(data),
    );
  }

  Future<FriendListPayload> fetchIncomingRequests() async {
    final data = await _client.getJson('/friends/requests');
    final list = data['requests'] as List<dynamic>? ?? [];
    return FriendListPayload(
      ids: list
          .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).userId)
          .toList(),
      profiles: _parseProfiles(data),
    );
  }

  Future<FriendListPayload> fetchSuggested({
    int limit = 10,
    int seed = 0,
  }) async {
    final data = await _client.getJson(
      '/friends/suggested',
      query: {'limit': '$limit', 'seed': '$seed'},
    );
    final list = data['users'] as List<dynamic>? ?? [];
    return FriendListPayload(
      ids: list
          .map((e) => (e as Map<String, dynamic>)['userId'] as String)
          .toList(),
      profiles: _parseProfiles(data),
    );
  }

  Future<FriendListPayload> fetchOutgoingRequests() async {
    final data = await _client.getJson('/friends/outgoing');
    final list = data['requests'] as List<dynamic>? ?? [];
    return FriendListPayload(
      ids: list
          .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).friendId)
          .toList(),
      profiles: _parseProfiles(data),
    );
  }

  Future<void> sendRequest(String friendId) async {
    await _client.postJson('/friends/request', body: {'friendId': friendId});
  }

  Future<void> acceptRequest(String requesterId) async {
    await _client.postJson('/friends/accept', body: {'requesterId': requesterId});
  }

  Future<void> declineRequest(String requesterId) async {
    await _client.postJson('/friends/decline', body: {'requesterId': requesterId});
  }

  Future<void> cancelRequest(String friendId) async {
    await _client.deleteJson('/friends/request/$friendId');
  }

  Future<void> removeFriend(String friendId) async {
    await _client.deleteJson('/friends/$friendId');
  }
}
