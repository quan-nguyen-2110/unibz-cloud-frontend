import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../mock/mock_users.dart';
import '../models/models.dart';
import '../repositories/api_friend_repository.dart';
import '../repositories/api_plan_repository.dart';
import '../repositories/api_user_repository.dart';
import '../repositories/mock_plan_repository.dart';
import '../repositories/plan_repository.dart';
import '../services/api_client.dart';
import '../services/auth_token_store.dart';
import '../services/jwt_util.dart';
import '../services/user_lookup.dart';

enum FriendStatus { friend, incoming, outgoing, none }

class AppState extends ChangeNotifier {
  AppState() {
    currentUser = null;
    _planRepo =
        AppConfig.useApi ? ApiPlanRepository() : MockPlanRepository(plans);
    _seedPlansIfNeeded();
  }

  late final PlanRepository _planRepo;
  final ApiClient _apiClient = ApiClient();
  final ApiFriendRepository _friendRepo = ApiFriendRepository();
  final ApiUserRepository _userRepo = ApiUserRepository();
  final UserLookup users = UserLookup();

  /// Last result from [probeBackend] (debug / Week 1 integration check).
  String? apiProbeMessage;

  SquadUser? currentUser;

  bool get isAuthenticated => currentUser != null;

  /// After login (Cognito JWT or local demo). Loads feed from API when [AppConfig.useApi].
  Future<void> completeLogin({String? email}) async {
    users.clear();
    if (AppConfig.useApi) {
      try {
        final me = await _userRepo.getMe();
        currentUser = me ?? _resolveCurrentUser(email: email);
      } catch (e) {
        currentUser = _resolveCurrentUser(email: email);
        apiProbeMessage = 'Profile sync failed: $e';
      }
      if (currentUser != null) users.seed(currentUser!);
      try {
        await refreshFriendsFromApi();
        await refreshFeedFromApi();
      } catch (e) {
        apiProbeMessage = 'Sync failed: $e';
        _seedPlansIfNeeded();
      }
    } else {
      currentUser = _resolveCurrentUser(email: email);
      _seedFriendGraphIfNeeded();
      _seedPlansIfNeeded();
    }
    notifyListeners();
  }

  /// Restore session when a Cognito token is already stored.
  Future<void> restoreSessionIfNeeded() async {
    if (isAuthenticated) return;
    final token = authTokenStore.accessToken;
    if (token == null || token.isEmpty) return;
    await completeLogin(email: JwtUtil.email(token));
  }

  SquadUser _resolveCurrentUser({String? email}) {
    final token = authTokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      final sub = JwtUtil.subject(token);
      if (sub != null) {
        final mail = email ?? JwtUtil.email(token) ?? 'user@squadup.app';
        final local = mockUserById(sub);
        if (local != null) return local;
        return SquadUser(
          id: sub,
          username: mail.split('@').first,
          displayName: mail.split('@').first,
          phone: '',
          city: '',
          avatarEmoji: '\u{1F9D1}',
        );
      }
    }
    return mockUserById('u_ali')!;
  }

  void _seedFriendGraphIfNeeded() {
    if (_friendGraphSeeded) return;
    _friendGraphSeeded = true;
    // Aligned with squadUp-layout/src/lib/mock.ts (724828d)
    friendIds.addAll({
      'u_sara',
      'u_omar',
      'u_mia',
      'u_tyler',
      'u_zara',
      'u_ravi',
      'alex-liu',
      'jamie-park',
    });
    incomingRequestIds.addAll({'sara-ahmed', 'kendra-lee'});
    outgoingRequestIds.addAll({'devon-brooks'});
  }

  bool _friendGraphSeeded = false;

  void logout() {
    currentUser = null;
    users.clear();
    authTokenStore.clear();
    notifyListeners();
  }

  /// Users resolved from [users] cache / mock roster for friend graph IDs.
  List<SquadUser> listUsersForIds(Iterable<String> ids) {
    final list = <SquadUser>[];
    final missing = <String>[];
    for (final id in ids) {
      final cached = users.cached(id);
      if (cached != null) {
        list.add(cached);
      } else {
        missing.add(id);
        list.add(
          SquadUser(
            id: id,
            username: id,
            displayName: '…',
            phone: '',
            city: '',
            avatarEmoji: '\u{1F9D1}',
          ),
        );
      }
    }
    if (missing.isNotEmpty && AppConfig.useApi) {
      users.prefetch(missing).then((_) => notifyListeners());
    }
    return list;
  }

  String displayNameFor(String userId) => users.displayNameFor(userId);
  /// Friends whose plans appear in the feed (includes layout-reference creators).
  final Set<String> friendIds = {
    'u_sara',
    'u_omar',
    'u_mia',
    'u_tyler',
    'u_zara',
    'u_ravi',
  };
  final Set<String> blockedUserIds = {};
  final List<SquadPlan> plans = [];

  /// Newly created plans shown at top of feed — `squadUp-layout` recentPlans.
  final List<SquadPlan> recentPlans = [];

  final Set<String> cancelledPlanIds = {};

  /// Friend requests — `squadUp-layout/src/lib/mock.ts`
  final Set<String> incomingRequestIds = {};
  final Set<String> outgoingRequestIds = {};

  void _seedPlansIfNeeded() {
    if (plans.isNotEmpty) return;
    final now = DateTime.now();
    DateTime todayAt(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);

    /// Seeds aligned with `squadUp-layout/src/lib/mock.ts` for UI parity.
    plans.addAll([
      SquadPlan(
        id: '1',
        creatorId: 'u_mia',
        vibeEmoji: '🏀',
        title: '3v3 at Riverside courts, bring water',
        startAt: todayAt(16, 0),
        threshold: 4,
        status: PlanStatus.active,
        source: PlanSource.manual,
        location: 'Riverside Basketball Courts',
        tapInUserIds: ['alex-liu', 'jordan-ortiz', 'sara-ahmed'],
      ),
      SquadPlan(
        id: '2',
        creatorId: 'u_tyler',
        vibeEmoji: '☕',
        title: 'Chill study sesh + coffee run, vibes only',
        startAt: todayAt(14, 30),
        threshold: 4,
        status: PlanStatus.active,
        source: PlanSource.manual,
        location: 'The Beanery Coffee',
        tapInUserIds: ['jamie-park', 'riley-chen'],
      ),
      SquadPlan(
        id: '3',
        creatorId: 'u_zara',
        vibeEmoji: '🏊',
        title: 'Rooftop pool session before sunset',
        startAt: todayAt(17, 30),
        threshold: 7,
        status: PlanStatus.active,
        source: PlanSource.manual,
        location: 'City View Pool',
        tapInUserIds: [
          'devon-brooks',
          'cassie-nguyen',
          'mo-hassan',
          'quinn-avery',
        ],
      ),
      SquadPlan(
        id: '4',
        creatorId: 'u_ravi',
        vibeEmoji: '🎮',
        title: 'Mario Kart tourney, snacks provided',
        startAt: todayAt(20, 0),
        threshold: 6,
        status: PlanStatus.active,
        source: PlanSource.manual,
        location: "Ravi's Place",
        tapInUserIds: ['kendra-lee', 'luca-romano'],
      ),
    ]);
  }

  SquadPlan? tryPlanById(String id) {
    for (final p in recentPlans) {
      if (p.id == id) return p;
    }
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Plans where the user is hosting or has tapped in (profile “In on”).
  List<SquadPlan> plansInvolvingUser(String userId) {
    final list = plans
        .where(
          (p) => p.creatorId == userId || p.tapInUserIds.contains(userId),
        )
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return list;
  }

  List<SquadUser> visibleUsers() {
    return kMockUsers
        .where(
          (u) =>
              u.id != currentUser?.id &&
              !blockedUserIds.contains(u.id) &&
              !blockedUserIds.contains(currentUser?.id),
        )
        .toList();
  }

  List<SquadUser> searchUsers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return visibleUsers().where((u) {
      return u.username.toLowerCase().contains(q) ||
          u.phone.replaceAll('+', '').contains(q) ||
          u.displayName.toLowerCase().contains(q);
    }).toList();
  }

  Future<List<SquadUser>> searchUsersRemote(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    if (!AppConfig.useApi) return searchUsers(q);
    final found = await _userRepo.search(q);
    for (final u in found) {
      users.seed(u);
    }
    return found;
  }

  /// Friends-of-friends style suggestions (fake ranking).
  /// Interest-overlap suggestions — layout `getSuggestedFriends`.
  List<SquadUser> suggestedFriends({int limit = 8}) {
    final mine = Set<String>.from(currentUser?.interests ?? []);
    final scored = <SquadUser, int>{};
    for (final u in visibleUsers()) {
      if (getFriendStatus(u.id) != FriendStatus.none) continue;
      final overlap =
          (u.interests ?? []).where((i) => mine.contains(i)).length;
      scored[u] = overlap;
    }
    final list = scored.keys.toList()
      ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
    return list.take(limit).toList();
  }

  List<SquadPlan> friendFeed() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    bool visible(SquadPlan p) {
      if (cancelledPlanIds.contains(p.id)) return false;
      if (p.status != PlanStatus.active && p.status != PlanStatus.locked) {
        return false;
      }
      if (blockedUserIds.contains(p.creatorId)) return false;
      final isMine = p.creatorId == uid;
      final isFriendPlan = friendIds.contains(p.creatorId);
      return isMine || isFriendPlan;
    }

    final merged = [...recentPlans, ...plans];
    return merged.where(visible).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  List<SquadPlan> feedRecentPlans() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    return recentPlans.where((p) {
      if (cancelledPlanIds.contains(p.id)) return false;
      return p.status == PlanStatus.active || p.status == PlanStatus.locked;
    }).toList();
  }

  List<SquadPlan> feedSquadPlans() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final recentIds = recentPlans.map((p) => p.id).toSet();
    return plans.where((p) {
      if (recentIds.contains(p.id)) return false;
      if (cancelledPlanIds.contains(p.id)) return false;
      if (p.status != PlanStatus.active && p.status != PlanStatus.locked) {
        return false;
      }
      if (blockedUserIds.contains(p.creatorId)) return false;
      final isMine = p.creatorId == uid;
      final isFriendPlan = friendIds.contains(p.creatorId);
      return isMine || isFriendPlan;
    }).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  bool isPlanCancelled(String planId) => cancelledPlanIds.contains(planId);

  bool isHost(SquadPlan plan) => plan.creatorId == currentUser?.id;

  Future<void> cancelPlan(String planId) async {
    if (AppConfig.useApi) {
      await _planRepo.cancelPlan(planId);
    }
    cancelledPlanIds.add(planId);
    notifyListeners();
  }

  FriendStatus getFriendStatus(String userId) {
    if (friendIds.contains(userId)) return FriendStatus.friend;
    if (incomingRequestIds.contains(userId)) return FriendStatus.incoming;
    if (outgoingRequestIds.contains(userId)) return FriendStatus.outgoing;
    return FriendStatus.none;
  }

  Future<void> sendFriendRequest(String userId) async {
    final me = currentUser?.id;
    if (me == null || userId == me) return;
    if (friendIds.contains(userId) || outgoingRequestIds.contains(userId)) {
      return;
    }
    if (incomingRequestIds.contains(userId)) {
      await acceptFriendRequest(userId);
      return;
    }
    if (AppConfig.useApi) {
      await _friendRepo.sendRequest(userId);
      await refreshFriendsFromApi();
      return;
    }
    outgoingRequestIds.add(userId);
    notifyListeners();
  }

  Future<void> cancelFriendRequest(String userId) async {
    if (AppConfig.useApi) {
      await _friendRepo.cancelRequest(userId);
      await refreshFriendsFromApi();
      return;
    }
    outgoingRequestIds.remove(userId);
    notifyListeners();
  }

  Future<void> acceptFriendRequest(String userId) async {
    if (AppConfig.useApi) {
      await _friendRepo.acceptRequest(userId);
      await refreshFriendsFromApi();
      return;
    }
    incomingRequestIds.remove(userId);
    outgoingRequestIds.remove(userId);
    friendIds.add(userId);
    notifyListeners();
  }

  Future<void> declineFriendRequest(String userId) async {
    if (AppConfig.useApi) {
      await _friendRepo.declineRequest(userId);
      await refreshFriendsFromApi();
      return;
    }
    incomingRequestIds.remove(userId);
    notifyListeners();
  }

  Future<void> removeFriend(String userId) async {
    if (AppConfig.useApi) {
      await _friendRepo.removeFriend(userId);
      await refreshFriendsFromApi();
      return;
    }
    friendIds.remove(userId);
    notifyListeners();
  }

  Future<void> addFriend(String userId) => sendFriendRequest(userId);

  void blockUser(String userId) {
    blockedUserIds.add(userId);
    friendIds.remove(userId);
    notifyListeners();
  }

  void unblockUser(String userId) {
    blockedUserIds.remove(userId);
    notifyListeners();
  }

  Future<void> addPlanFromDraft(PlanDraft draft, PlanSource source) async {
    final uid = currentUser?.id ?? 'u_me';
    final acts = draft.activities.isNotEmpty
        ? draft.activities
            .map((a) {
              final loc = a.location?.trim();
              final dm = a.durationMinutes;
              return PlanActivity(
                emoji: a.emoji,
                title: a.title.trim(),
                location: (loc == null || loc.isEmpty) ? null : loc,
                durationMinutes: (dm != null && dm > 0) ? dm : null,
              );
            })
            .where((a) => a.title.isNotEmpty)
            .toList()
        : [
            PlanActivity(
              emoji: draft.vibeEmoji,
              title: draft.title.trim(),
              location: (draft.location == null || draft.location!.trim().isEmpty)
                  ? null
                  : draft.location!.trim(),
              durationMinutes: null,
            ),
          ];
    if (acts.isEmpty) return;

    if (AppConfig.useApi) {
      try {
        final apiDraft = PlanDraft(
          vibeEmoji: draft.vibeEmoji,
          title: draft.title,
          startAt: draft.startAt,
          description: draft.description,
          activities: acts,
          location: draft.location,
          gameName: draft.gameName,
          threshold: draft.threshold,
          transcript: draft.transcript,
        );
        var plan = await _planRepo.createPlan(apiDraft, source);
        await _planRepo.tapIn(plan.id);
        plan = await _planRepo.getPlan(plan.id) ?? plan;
        recentPlans.insert(0, plan);
        await users.prefetch([plan.creatorId, ...plan.tapInUserIds]);
        notifyListeners();
      } catch (e) {
        apiProbeMessage = 'Create plan failed: $e';
        notifyListeners();
      }
      return;
    }

    final headline = draft.title.trim().isNotEmpty
        ? draft.title.trim()
        : acts.map((a) => a.title).join(' · ');
    final desc = draft.description?.trim();
    final plan = SquadPlan(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: uid,
      vibeEmoji: acts.first.emoji,
      title: headline,
      description: (desc == null || desc.isEmpty) ? null : desc,
      activities: acts,
      startAt: draft.startAt,
      threshold: draft.threshold,
      status: PlanStatus.active,
      source: source,
      gameName: draft.gameName,
      location: draft.location,
      transcript: draft.transcript,
      tapInUserIds: [],
    );
    recentPlans.insert(0, plan);
    plan.tapInUserIds.add(uid);
    notifyListeners();
  }

  SquadPlan? _findPlan(String planId) {
    for (final p in recentPlans) {
      if (p.id == planId) return p;
    }
    for (final p in plans) {
      if (p.id == planId) return p;
    }
    return null;
  }

  void _replacePlan(SquadPlan updated) {
    for (var i = 0; i < recentPlans.length; i++) {
      if (recentPlans[i].id == updated.id) {
        recentPlans[i] = updated;
        return;
      }
    }
    for (var i = 0; i < plans.length; i++) {
      if (plans[i].id == updated.id) {
        plans[i] = updated;
        return;
      }
    }
  }

  Future<void> _syncPlanFromApi(String planId) async {
    final remote = await _planRepo.getPlan(planId);
    if (remote == null) return;
    _replacePlan(remote);
    await users.prefetch([remote.creatorId, ...remote.tapInUserIds]);
  }

  /// Null if join was a no-op. Otherwise signals whether the squad just locked.
  Future<TapInOutcome?> tapIn(String planId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    if (AppConfig.useApi) {
      final plan = _findPlan(planId);
      if (plan == null) return null;
      if (plan.status != PlanStatus.active) return null;
      if (plan.userHasTappedIn(uid)) return null;
      try {
        final outcome = await _planRepo.tapIn(planId);
        await _syncPlanFromApi(planId);
        notifyListeners();
        return outcome;
      } catch (e) {
        apiProbeMessage = 'Tap-in failed: $e';
        notifyListeners();
        return null;
      }
    }

    final plan = _findPlan(planId);
    if (plan == null) return null;
    if (plan.status != PlanStatus.active) return null;
    if (plan.userHasTappedIn(uid)) return null;
    plan.tapInUserIds.add(uid);
    var locked = false;
    if (plan.tapInCount >= plan.threshold) {
      plan.status = PlanStatus.locked;
      locked = true;
    }
    notifyListeners();
    return TapInOutcome(squadLocked: locked);
  }

  /// Withdraw tap-in while the plan is still [PlanStatus.active]. No-op if locked/completed.
  Future<void> tapOut(String planId) async {
    final uid = currentUser?.id;
    if (uid == null) return;

    if (AppConfig.useApi) {
      final plan = _findPlan(planId);
      if (plan == null || plan.status != PlanStatus.active) return;
      try {
        await _planRepo.tapOut(planId);
        await _syncPlanFromApi(planId);
        notifyListeners();
      } catch (e) {
        apiProbeMessage = 'Leave failed: $e';
        notifyListeners();
      }
      return;
    }

    final plan = _findPlan(planId);
    if (plan == null || plan.status != PlanStatus.active) return;
    final removed = plan.tapInUserIds.remove(uid);
    if (removed) notifyListeners();
  }

  int plansPostedCount() {
    final uid = currentUser?.id;
    if (uid == null) return 0;
    return plans.where((p) => p.creatorId == uid).length;
  }

  /// Fake streak count with Sara for profile demo.
  int streakWithSara() {
    return 7;
  }

  SquadPlan? latestCompletedForRecap() {
    final completed =
        plans.where((p) => p.status == PlanStatus.completed).toList();
    if (completed.isEmpty) {
      // Fake recap from a locked plan for prototype visuals.
      final locked = plans.where((p) => p.status == PlanStatus.locked).toList();
      if (locked.isEmpty) return null;
      locked.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return locked.first;
    }
    completed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return completed.first;
  }

  /// Simulate friends joining a plan (demo).
  /// Week 1: hit `/healthz` then protected `GET /plans/feed` (dev header or JWT).
  Future<String> probeBackend() async {
    try {
      final healthy = await _apiClient.checkHealth();
      if (!healthy) {
        apiProbeMessage = 'Health failed — is the API running at ${AppConfig.apiBaseUrl}?';
        notifyListeners();
        return apiProbeMessage!;
      }
      final feed = await ApiPlanRepository(client: _apiClient).fetchFeed();
      apiProbeMessage = 'API OK — ${feed.length} plan(s) from feed';
      if (AppConfig.useApi) {
        plans
          ..clear()
          ..addAll(feed);
      }
      notifyListeners();
      return apiProbeMessage!;
    } catch (e) {
      apiProbeMessage = 'API error: $e';
      notifyListeners();
      return apiProbeMessage!;
    }
  }

  /// Sync feed from API when [AppConfig.useApi] is true.
  Future<void> refreshFeedFromApi() async {
    if (!AppConfig.useApi) return;
    final feed = await (_planRepo as ApiPlanRepository).fetchFeed();
    plans
      ..clear()
      ..addAll(feed);
    final ids = <String>{};
    for (final p in feed) {
      ids.add(p.creatorId);
      ids.addAll(p.tapInUserIds);
    }
    await users.prefetch(ids);
    notifyListeners();
  }

  /// Sync friend graph from API when [AppConfig.useApi] is true.
  Future<void> refreshFriendsFromApi() async {
    if (!AppConfig.useApi) return;
    friendIds.clear();
    incomingRequestIds.clear();
    outgoingRequestIds.clear();
    friendIds.addAll(await _friendRepo.fetchFriendIds());
    incomingRequestIds.addAll(await _friendRepo.fetchIncomingRequesterIds());
    outgoingRequestIds.addAll(await _friendRepo.fetchOutgoingFriendIds());
    await users.prefetch([
      ...friendIds,
      ...incomingRequestIds,
      ...outgoingRequestIds,
    ]);
    notifyListeners();
  }

  void demoSimulateJoins(String planId) {
    SquadPlan? plan;
    for (final p in plans) {
      if (p.id == planId) plan = p;
    }
    if (plan == null) return;
    for (final id in ['u_sara', 'u_omar']) {
      if (!plan.tapInUserIds.contains(id)) {
        plan.tapInUserIds.add(id);
      }
      if (plan.tapInCount >= plan.threshold) {
        plan.status = PlanStatus.locked;
        break;
      }
    }
    notifyListeners();
  }
}
