import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../repositories/api_friend_repository.dart';
import '../repositories/api_plan_repository.dart';
import '../repositories/api_user_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/auth_token_store.dart';
import '../services/jwt_util.dart';
import '../services/user_lookup.dart';

enum FriendStatus { friend, incoming, outgoing, none }

class AppState extends ChangeNotifier {
  AppState() {
    currentUser = null;
    _planRepo = ApiPlanRepository();
  }

  late final ApiPlanRepository _planRepo;
  final ApiClient _apiClient = ApiClient();
  final ApiFriendRepository _friendRepo = ApiFriendRepository();
  final ApiUserRepository _userRepo = ApiUserRepository();
  final UserLookup users = UserLookup();

  String? apiProbeMessage;
  SquadUser? currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Local Docker: skip Cognito; uses [AppConfig.devUserId] + `X-Dev-User-Id`.
  Future<void> completeDevLogin() async {
    if (!AppConfig.useDevAuth) return;
    final devId = AppConfig.devUserId.trim();
    if (devId.isEmpty) return;

    users.clear();
    apiProbeMessage = null;
    try {
      final me = await _userRepo.getMe();
      currentUser = me ?? _localDevUser(devId);
    } catch (e) {
      currentUser = _localDevUser(devId);
      apiProbeMessage = 'Profile sync failed: $e';
    }
    if (currentUser != null) users.seed(currentUser!);
    try {
      await refreshSquadFromApi();
    } catch (e) {
      apiProbeMessage = 'Sync failed: $e';
    }
    notifyListeners();
  }

  SquadUser _localDevUser(String id) {
    return SquadUser(
      id: id,
      username: 'devuser',
      displayName: 'Dev User',
      phone: '',
      city: '',
      avatarEmoji: '\u{1F9D1}',
    );
  }

  Future<void> completeLogin({String? email}) async {
    users.clear();
    try {
      final me = await _userRepo.getMe();
      currentUser = me ?? _userFromToken(email: email);
    } catch (e) {
      currentUser = _userFromToken(email: email);
      apiProbeMessage = 'Profile sync failed: $e';
    }
    if (currentUser != null) users.seed(currentUser!);
    try {
      await refreshSquadFromApi();
    } catch (e) {
      apiProbeMessage = 'Sync failed: $e';
    }
    notifyListeners();
  }

  Future<void> restoreSessionIfNeeded() async {
    if (isAuthenticated) return;
    final token = authTokenStore.accessToken;
    if (token == null || token.isEmpty) return;
    await completeLogin(email: JwtUtil.email(token));
  }

  SquadUser? _userFromToken({String? email}) {
    final token = authTokenStore.accessToken;
    if (token == null || token.isEmpty) return null;
    final sub = JwtUtil.subject(token);
    if (sub == null) return null;
    final mail = email ?? JwtUtil.email(token) ?? 'user@squadup.app';
    final handle = mail.split('@').first;
    return SquadUser(
      id: sub,
      username: handle,
      displayName: handle,
      phone: '',
      city: '',
      avatarEmoji: '\u{1F9D1}',
    );
  }

  /// Persists [displayName], [bio], and [profileLocation] (as city) via API; age and interests are local.
  Future<SquadUser> updateMyProfile({
    required String displayName,
    required String bio,
    int? age,
    String? profileLocation,
    List<String>? interests,
  }) async {
    final me = currentUser;
    if (me == null) {
      throw Exception('Not logged in');
    }

    final loc = profileLocation?.trim();

    await _userRepo.updateMe(
      displayName: displayName,
      bio: bio,
      city: (loc != null && loc.isNotEmpty) ? loc : null,
    );

    final updated = SquadUser(
      id: me.id,
      username: me.username,
      displayName: displayName,
      phone: me.phone,
      city: (loc != null && loc.isNotEmpty) ? loc : me.city,
      avatarEmoji: me.avatarEmoji,
      age: age,
      genderLabel: me.genderLabel,
      bio: bio.isEmpty ? null : bio,
      interests: (interests == null || interests.isEmpty) ? null : interests,
      profileLocation: loc?.isEmpty ?? true ? null : loc,
      avatarUrl: me.avatarUrl,
    );
    currentUser = updated;
    users.seed(updated);
    notifyListeners();
    return updated;
  }

  void logout() {
    currentUser = null;
    users.clear();
    AuthService().logout();
    friendIds.clear();
    incomingRequestIds.clear();
    outgoingRequestIds.clear();
    plans.clear();
    recentPlans.clear();
    cancelledPlanIds.clear();
    notifyListeners();
  }

  /// Display list from cache only. Call [refreshFriendsFromApi] / [refreshFeedFromApi]
  /// to load users — do not prefetch here (avoids rebuild loops).
  List<SquadUser> listUsersForIds(Iterable<String> ids) {
    final list = <SquadUser>[];
    for (final id in ids) {
      final cached = users.cached(id);
      if (cached != null) {
        list.add(cached);
      } else {
        list.add(
          SquadUser(
            id: id,
            username: id.length > 8 ? id.substring(0, 8) : id,
            displayName: '…',
            phone: '',
            city: '',
            avatarEmoji: '\u{1F9D1}',
          ),
        );
      }
    }
    return list;
  }

  String displayNameFor(String userId) => users.displayNameFor(userId);

  final Set<String> friendIds = {};
  final Set<String> blockedUserIds = {};
  final List<SquadPlan> plans = [];
  final List<SquadPlan> recentPlans = [];
  final Set<String> cancelledPlanIds = {};
  final Set<String> incomingRequestIds = {};
  final Set<String> outgoingRequestIds = {};

  SquadPlan? tryPlanById(String id) {
    for (final p in recentPlans) {
      if (p.id == id) return p;
    }
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<SquadPlan> plansInvolvingUser(String userId) {
    final list = plans
        .where(
          (p) => p.creatorId == userId || p.tapInUserIds.contains(userId),
        )
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    return list;
  }

  Future<List<SquadUser>> searchUsersRemote(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final me = currentUser?.id;
    final found = await _userRepo.search(q);
    final others = me == null
        ? found
        : found.where((u) => u.id != me).toList();
    for (final u in others) {
      users.seed(u);
    }
    return others;
  }

  List<SquadUser> suggestedFriends({int limit = 8}) => const [];

  List<SquadPlan> friendFeed() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    bool visible(SquadPlan p) {
      if (cancelledPlanIds.contains(p.id)) return false;
      if (p.status != PlanStatus.active && p.status != PlanStatus.locked) {
        return false;
      }
      if (blockedUserIds.contains(p.creatorId)) return false;
      if (p.creatorId == uid) return true;
      if (friendIds.contains(p.creatorId)) return true;
      if (!p.isPrivate) return true;
      return false;
    }

    final merged = [...recentPlans, ...plans];
    return merged.where(visible).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  List<SquadPlan> feedRecentPlans() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    return friendFeed().where((p) => p.creatorId == uid).toList();
  }

  /// Friends' plans (and yours from the API feed, excluding recent-session dupes).
  List<SquadPlan> feedSquadPlans() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final recentIds = recentPlans.map((p) => p.id).toSet();
    return friendFeed()
        .where((p) => !recentIds.contains(p.id) && p.creatorId != uid)
        .toList();
  }

  bool isPlanCancelled(String planId) => cancelledPlanIds.contains(planId);

  bool isHost(SquadPlan plan) => plan.creatorId == currentUser?.id;

  Future<void> cancelPlan(String planId) async {
    await _planRepo.cancelPlan(planId);
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
    await _friendRepo.sendRequest(userId);
    await refreshFriendsFromApi();
  }

  Future<void> cancelFriendRequest(String userId) async {
    await _friendRepo.cancelRequest(userId);
    await refreshFriendsFromApi();
  }

  Future<void> acceptFriendRequest(String userId) async {
    await _friendRepo.acceptRequest(userId);
    await refreshSquadFromApi();
  }

  Future<void> declineFriendRequest(String userId) async {
    await _friendRepo.declineRequest(userId);
    await refreshFriendsFromApi();
  }

  Future<void> removeFriend(String userId) async {
    await _friendRepo.removeFriend(userId);
    await refreshSquadFromApi();
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
        visibility: draft.visibility,
      );
      var plan = await _planRepo.createPlan(apiDraft, source);
      await _planRepo.tapIn(plan.id);
      plan = await _planRepo.getPlan(plan.id) ?? plan;
      recentPlans.insert(0, plan);
      final existing = plans.indexWhere((p) => p.id == plan.id);
      if (existing >= 0) {
        plans[existing] = plan;
      } else {
        plans.insert(0, plan);
      }
      await users.prefetch([plan.creatorId, ...plan.tapInUserIds]);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Create plan failed: $e';
      notifyListeners();
    }
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

  Future<TapInOutcome?> tapIn(String planId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

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

  Future<void> tapOut(String planId) async {
    final uid = currentUser?.id;
    if (uid == null) return;

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
  }

  int plansPostedCount() {
    final uid = currentUser?.id;
    if (uid == null) return 0;
    return plans.where((p) => p.creatorId == uid).length;
  }

  Future<String> probeBackend() async {
    try {
      final healthy = await _apiClient.checkHealth();
      if (!healthy) {
        apiProbeMessage =
            'Health failed — is the API running at ${AppConfig.apiBaseUrl}?';
        notifyListeners();
        return apiProbeMessage!;
      }
      final feed = await ApiPlanRepository(client: _apiClient).fetchFeed();
      apiProbeMessage = 'API OK — ${feed.length} plan(s) from feed';
      plans
        ..clear()
        ..addAll(feed);
      notifyListeners();
      return apiProbeMessage!;
    } catch (e) {
      apiProbeMessage = 'API error: $e';
      notifyListeners();
      return apiProbeMessage!;
    }
  }

  /// Friends list + feed (dashboard shows plans from accepted friends).
  Future<void> refreshSquadFromApi() async {
    await refreshFriendsFromApi();
    await refreshFeedFromApi();
  }

  Future<void> refreshFeedFromApi() async {
    try {
      final feed = await _planRepo.fetchFeed();
      plans
        ..clear()
        ..addAll(feed);
      final ids = <String>{};
      for (final p in feed) {
        ids.add(p.creatorId);
        ids.addAll(p.tapInUserIds);
      }
      apiProbeMessage = null;
      await users.prefetch(ids);
    } catch (e) {
      apiProbeMessage = 'Feed sync failed: $e';
    }
    notifyListeners();
  }

  Future<void> refreshFriendsFromApi() async {
    try {
      friendIds.clear();
      incomingRequestIds.clear();
      outgoingRequestIds.clear();

      final friends = await _friendRepo.fetchFriends();
      final incoming = await _friendRepo.fetchIncomingRequests();
      final outgoing = await _friendRepo.fetchOutgoingRequests();

      friendIds.addAll(friends.ids);
      incomingRequestIds.addAll(incoming.ids);
      outgoingRequestIds.addAll(outgoing.ids);

      final allIds = [
        ...friendIds,
        ...incomingRequestIds,
        ...outgoingRequestIds,
      ];
      users.resetUnresolved(allIds);
      users.seedProfiles([
        ...friends.profiles,
        ...incoming.profiles,
        ...outgoing.profiles,
      ]);
      await users.prefetch(allIds);
      apiProbeMessage = null;
    } catch (e) {
      apiProbeMessage = 'Friends sync failed: $e';
    }
    notifyListeners();
  }
}
