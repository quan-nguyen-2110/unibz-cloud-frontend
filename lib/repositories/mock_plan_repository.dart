import '../models/models.dart';
import 'plan_repository.dart';

/// In-memory plan store (prototype / offline).
class MockPlanRepository implements PlanRepository {
  MockPlanRepository(this._plans);

  final List<SquadPlan> _plans;

  @override
  Future<List<SquadPlan>> fetchFeed({String status = 'active'}) async {
    return List<SquadPlan>.from(_plans);
  }

  @override
  Future<SquadPlan?> getPlan(String id) async {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<SquadPlan> createPlan(PlanDraft draft, PlanSource source) async {
    throw UnsupportedError('Use AppState.addPlanFromDraft for mock mode');
  }

  @override
  Future<TapInOutcome?> tapIn(String planId) async {
    throw UnsupportedError('Use AppState.tapIn for mock mode');
  }

  @override
  Future<void> tapOut(String planId) async {
    throw UnsupportedError('Use AppState.tapOut for mock mode');
  }

  @override
  Future<void> cancelPlan(String planId) async {
    throw UnsupportedError('Use AppState.cancelPlan for mock mode');
  }
}
