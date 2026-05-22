import '../models/models.dart';

/// Data access for plans — mock (in-memory) or HTTP API.
abstract class PlanRepository {
  Future<List<SquadPlan>> fetchFeed({String status = 'active'});
  Future<SquadPlan?> getPlan(String id);
  Future<SquadPlan> createPlan(PlanDraft draft, PlanSource source);
  Future<TapInOutcome?> tapIn(String planId);
  Future<void> tapOut(String planId);
  Future<void> cancelPlan(String planId);
}
