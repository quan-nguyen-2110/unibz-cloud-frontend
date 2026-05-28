import '../models/models.dart';

/// One page of dashboard feed results from `GET /plans/feed`.
class FeedPage {
  const FeedPage({
    required this.plans,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<SquadPlan> plans;
  final bool hasMore;
  final int nextOffset;
}

/// Data access for plans via HTTP API.
abstract class PlanRepository {
  Future<FeedPage> fetchFeed({
    String status = 'active',
    int limit = 10,
    int offset = 0,
  });
  Future<SquadPlan?> getPlan(String id);
  Future<SquadPlan> createPlan(PlanDraft draft, PlanSource source);
  Future<TapInOutcome?> tapIn(String planId);
  Future<void> tapOut(String planId);
  Future<void> removeAttendee(String planId, String userId);
  Future<void> cancelPlan(String planId);
  Future<SquadPlan> updatePlan(String planId, PlanDraft draft);
  Future<List<SquadPlan>> fetchRecaps();
  Future<SquadPlan> setProfileShare(String planId, {required bool shared});
}
