import '../models/api_json.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import 'plan_repository.dart';

class ApiPlanRepository implements PlanRepository {
  ApiPlanRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<SquadPlan>> fetchFeed({String status = 'active'}) async {
    final data = await _client.getJson('/plans/feed', query: {
      'status': status,
      'limit': '50',
    });
    final list = data['plans'] as List<dynamic>? ?? [];
    return list
        .map((e) => squadPlanFromJson(e as Map<String, dynamic>))
        .toList();
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
  Future<void> cancelPlan(String planId) async {
    await _client.deleteJson('/plans/$planId');
  }

  Future<List<String>> fetchTapIns(String planId) async {
    final data = await _client.getJson('/plans/$planId/tap-ins');
    return (data['tapInUserIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
  }
}
