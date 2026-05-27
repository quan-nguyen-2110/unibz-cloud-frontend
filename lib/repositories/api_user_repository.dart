import '../models/api_json.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class ApiUserRepository {
  ApiUserRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SquadUser?> getUser(String id) async {
    try {
      final data = await _client.getJson('/users/$id');
      final raw = data['user'];
      if (raw is! Map<String, dynamic>) return null;
      return squadUserFromJson(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 400) return null;
      rethrow;
    }
  }

  Future<SquadUser?> getMe() async {
    try {
      final data = await _client.getJson('/users/me');
      final raw = data['user'];
      if (raw is! Map<String, dynamic>) return null;
      return squadUserFromJson(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<SquadUser>> search(String query) async {
    final data = await _client.getJson('/users/search', query: {'q': query});
    final list = data['users'] as List<dynamic>? ?? [];
    return list
        .map((e) => squadUserFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateMe({String? displayName, String? bio, String? city}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (city != null) body['city'] = city;
    if (body.isEmpty) return;
    await _client.putJson('/users/me', body: body);
  }

  Future<List<SquadPlan>> fetchProfileRecaps(String userId) async {
    final data = await _client.getJson('/users/$userId/profile-recaps');
    final list = data['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => squadPlanFromJson(e as Map<String, dynamic>))
        .toList();
  }
}
