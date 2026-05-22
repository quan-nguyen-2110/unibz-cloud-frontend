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

class ApiFriendRepository {
  ApiFriendRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<String>> fetchFriendIds() async {
    final data = await _client.getJson('/friends');
    final list = data['friends'] as List<dynamic>? ?? [];
    return list
        .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).friendId)
        .toList();
  }

  Future<List<String>> fetchIncomingRequesterIds() async {
    final data = await _client.getJson('/friends/requests');
    final list = data['requests'] as List<dynamic>? ?? [];
    return list
        .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).userId)
        .toList();
  }

  Future<List<String>> fetchOutgoingFriendIds() async {
    final data = await _client.getJson('/friends/outgoing');
    final list = data['requests'] as List<dynamic>? ?? [];
    return list
        .map((e) => FriendEdge.fromJson(e as Map<String, dynamic>).friendId)
        .toList();
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
