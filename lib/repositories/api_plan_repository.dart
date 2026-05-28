import '../models/api_json.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'plan_repository.dart';

class ApiPlanRepository implements PlanRepository {
  ApiPlanRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<FeedPage> fetchFeed({
    String status = 'active',
    int limit = 10,
    int offset = 0,
  }) async {
    final data = await _client.getJson('/plans/feed', query: {
      'status': status,
      'limit': '$limit',
      'offset': '$offset',
    });
    final list = data['plans'] as List<dynamic>? ?? [];
    final plans = list
        .map((e) => squadPlanFromJson(e as Map<String, dynamic>))
        .toList();
    return FeedPage(
      plans: plans,
      hasMore: data['hasMore'] as bool? ?? false,
      nextOffset: data['nextOffset'] as int? ?? offset + plans.length,
    );
  }

  @override
  Future<SquadPlan?> getPlan(String id) async {
    final data = await _client.getJson('/plans/$id');
    final plan = data['plan'];
    if (plan == null) return null;
    return squadPlanFromJson(plan as Map<String, dynamic>);
  }

  @override
  Future<SquadPlan> createPlan(PlanDraft draft, PlanSource source) async {
    final data = await _client.postJson(
      '/plans',
      body: planDraftToJson(draft, source),
    );
    return squadPlanFromJson(data['plan'] as Map<String, dynamic>);
  }

  @override
  Future<TapInOutcome?> tapIn(String planId) async {
    final data = await _client.postJson('/plans/$planId/tap-in');
    return tapInOutcomeFromJson(data);
  }

  @override
  Future<void> tapOut(String planId) async {
    await _client.deleteJson('/plans/$planId/tap-in');
  }

  @override
  Future<void> removeAttendee(String planId, String userId) async {
    await _client.deleteJson('/plans/$planId/attendees/$userId');
  }

  @override
  Future<void> cancelPlan(String planId) async {
    await _client.deleteJson('/plans/$planId');
  }

  @override
  Future<SquadPlan> updatePlan(String planId, PlanDraft draft) async {
    final data = await _client.putJson(
      '/plans/$planId',
      body: planDraftToJson(draft, PlanSource.manual),
    );
    return squadPlanFromJson(data['plan'] as Map<String, dynamic>);
  }

  @override
  Future<List<SquadPlan>> fetchRecaps() async {
    final data = await _client.getJson('/plans/recaps');
    final list = data['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => squadPlanFromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SquadPlan> setProfileShare(
    String planId, {
    required bool shared,
  }) async {
    final data = await _client.patchJson(
      '/plans/$planId/profile-share',
      body: {'sharedToProfile': shared},
    );
    return squadPlanFromJson(data['plan'] as Map<String, dynamic>);
  }

  Future<List<String>> fetchTapIns(String planId) async {
    final data = await _client.getJson('/plans/$planId/tap-ins');
    return (data['tapInUserIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
  }

  /// AI-generated short labels for [emojis] (Bedrock); cached on the server.
  Future<Map<String, String>> fetchVibeLabels(List<String> emojis) async {
    if (emojis.isEmpty) return {};
    final data = await _client.postJson(
      '/plans/vibe-labels',
      body: {'emojis': emojis},
      silent: true,
    );
    final raw = data['labels'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, v.toString()));
  }
}
