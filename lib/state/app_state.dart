import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../repositories/api_friend_repository.dart';
import '../repositories/api_plan_repository.dart';
import '../repositories/api_user_repository.dart';
import '../services/api_client.dart';
import '../services/api_loading.dart';
import '../services/auth_service.dart';
import '../services/auth_token_store.dart';
import '../services/jwt_util.dart';
import '../services/feed_hub_service.dart';
import '../services/notification_service.dart';
import '../services/plan_photo_service.dart';
import '../services/user_lookup.dart';

enum FriendStatus { friend, incoming, outgoing, none }

class AppState extends ChangeNotifier {
  AppState() {
    currentUser = null;
    _planRepo = ApiPlanRepository();
  }

  late final ApiPlanRepository _planRepo;
  final PlanPhotoService _planPhotos = PlanPhotoService();
  final ApiClient _apiClient = ApiClient();
  final ApiFriendRepository _friendRepo = ApiFriendRepository();
  final ApiUserRepository _userRepo = ApiUserRepository();
  final UserLookup users = UserLookup();
  final FeedHubService _feedHub = FeedHubService();
  final NotificationService _notificationService = NotificationService();

  String? apiProbeMessage;
  /// AI labels for feed filter chips (`POST /plans/vibe-labels`).
  final Map<String, String> vibeEmojiLabels = {};
  SquadUser? currentUser;
  List<SquadNotification> notifications = [];
  String? planCancelledToast;
  String? planCancelledToastPlanId;
  String? removedFromPlanToast;
  String? removedFromPlanToastPlanId;

  /// Non-null while plan photos are uploading (create flow or plan detail).
  PlanPhotoUploadProgress? planPhotoUploadProgress;

  int? shellTabRequest;

  bool isUploadingPlanPhotos(String planId) =>
      planPhotoUploadProgress?.planId == planId;

  void openShellTab(int index) {
    shellTabRequest = index;
    notifyListeners();
  }

  void consumeShellTabRequest() {
    shellTabRequest = null;
  }

  /// Set by [HomeShell] to play confetti when a plan locks via realtime sync.
  void Function()? onSquadLockedCelebration;

  final Set<String> _pendingPlanSyncs = {};
  final Set<String> _pendingLockCelebrations = {};
  Timer? _planSyncDebounce;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.read).length;

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
      await _connectRealtime();
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
      await _connectRealtime();
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
    String? avatarUrl,
    bool replaceAvatar = false,
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
      avatarUrl: replaceAvatar ? avatarUrl : (avatarUrl ?? me.avatarUrl),
    );
    currentUser = updated;
    users.seed(updated);
    notifyListeners();
    return updated;
  }

  void logout() {
    _disconnectRealtime();
    currentUser = null;
    users.clear();
    AuthService().logout();
    friendIds.clear();
    incomingRequestIds.clear();
    outgoingRequestIds.clear();
    suggestedFriends = [];
    _suggestedSeed = 0;
    suggestedFriendsLoading = false;
    plans.clear();
    recentPlans.clear();
    feedLoading = false;
    feedLoadingMore = false;
    feedHasMore = true;
    _feedNextOffset = 0;
    recapPlans.clear();
    recapPlansError = null;
    cancelledPlanIds.clear();
    notifications.clear();
    planCancelledToast = null;
    planCancelledToastPlanId = null;
    removedFromPlanToast = null;
    removedFromPlanToastPlanId = null;
    planPhotoUploadProgress = null;
    notifyListeners();
  }

  Future<void> _connectRealtime() async {
    _feedHub.onPlanCancelled = _onPlanCancelledHub;
    _feedHub.onInboxNotification = _onInboxNotificationHub;
    _feedHub.onFeedPlanEvent = _onFeedPlanHub;
    _feedHub.onReconnected = _onFeedHubReconnected;
    try {
      await _feedHub.connect();
      await refreshNotifications();
    } catch (e) {
      apiProbeMessage = 'Realtime connect failed: $e';
    }
  }

  void _disconnectRealtime() {
    _planSyncDebounce?.cancel();
    _planSyncDebounce = null;
    _pendingPlanSyncs.clear();
    _pendingLockCelebrations.clear();
    _feedHub.onPlanCancelled = null;
    _feedHub.onInboxNotification = null;
    _feedHub.onFeedPlanEvent = null;
    _feedHub.onReconnected = null;
    unawaited(_feedHub.disconnect());
  }

  void _onFeedHubReconnected() {
    if (!isAuthenticated) return;
    unawaited(
      ApiLoading.runSilently(refreshSquadFromApi),
    );
  }

  void _onFeedPlanHub(FeedPlanHubEvent event) {
    switch (event.kind) {
      case FeedPlanHubKind.created:
      case FeedPlanHubKind.updated:
        final plan = event.plan;
        if (plan == null) return;
        _upsertPlanFromHub(plan);
        notifyListeners();
        return;
      case FeedPlanHubKind.tapIn:
      case FeedPlanHubKind.tapOut:
        final uid = currentUser?.id;
        if (uid != null &&
            event.userId != null &&
            event.userId == uid) {
          return;
        }
        final id = event.planId;
        if (id == null || id.isEmpty) return;
        _schedulePlanSync(id);
        return;
      case FeedPlanHubKind.locked:
        final id = event.planId;
        if (id == null || id.isEmpty) return;
        _schedulePlanSync(id, celebrateOnLock: true);
        return;
    }
  }

  void _schedulePlanSync(String planId, {bool celebrateOnLock = false}) {
    _pendingPlanSyncs.add(planId);
    if (celebrateOnLock) _pendingLockCelebrations.add(planId);
    _planSyncDebounce?.cancel();
    _planSyncDebounce = Timer(const Duration(milliseconds: 300), () {
      final ids = _pendingPlanSyncs.toList();
      final lockIds = _pendingLockCelebrations.toList();
      _pendingPlanSyncs.clear();
      _pendingLockCelebrations.clear();
      unawaited(_flushPlanSyncs(ids, lockIds));
    });
  }

  Future<void> _flushPlanSyncs(
    List<String> planIds,
    List<String> celebrateLockPlanIds,
  ) async {
    await ApiLoading.runSilently(() async {
      var celebrate = false;
      for (final id in planIds) {
        try {
          final before = _findPlan(id)?.status;
          await _syncPlanFromApi(id);
          final after = _findPlan(id)?.status;
          if (before == PlanStatus.active &&
              after == PlanStatus.locked &&
              celebrateLockPlanIds.contains(id)) {
            celebrate = true;
          }
        } catch (_) {
          /* keep other syncs */
        }
      }
      notifyListeners();
      if (celebrate) onSquadLockedCelebration?.call();
    });
  }

  bool _shouldShowInFeed(SquadPlan plan) {
    final uid = currentUser?.id;
    if (uid == null) return false;
    if (cancelledPlanIds.contains(plan.id)) return false;
    if (plan.status != PlanStatus.active && plan.status != PlanStatus.locked) {
      return false;
    }
    if (blockedUserIds.contains(plan.creatorId)) return false;
    if (plan.creatorId == uid) return true;
    if (friendIds.contains(plan.creatorId)) return true;
    if (!plan.isPrivate) return true;
    return false;
  }

  void _upsertPlanFromHub(SquadPlan plan) {
    if (cancelledPlanIds.contains(plan.id)) return;

    final existing = tryPlanById(plan.id);
    final merged = _mergePlanPreservePhotos(plan, existing);
    if (existing != null) {
      _replacePlan(merged);
      unawaited(users.prefetch([merged.creatorId, ...merged.tapInUserIds]));
      return;
    }

    if (!_shouldShowInFeed(merged)) return;

    plans.insert(0, merged);
    unawaited(users.prefetch([merged.creatorId, ...merged.tapInUserIds]));
  }

  void _onPlanCancelledHub(PlanCancelledHubEvent event) {
    cancelledPlanIds.add(event.planId);
    planCancelledToast = event.message;
    planCancelledToastPlanId = event.planId;
    notifyListeners();
  }

  void _onInboxNotificationHub(InboxNotificationHubEvent event) {
    if (event.type == 'removed_from_plan') {
      removedFromPlanToast =
          event.body.isNotEmpty ? event.body : event.title;
      removedFromPlanToastPlanId = event.planId;
      final planId = event.planId;
      if (planId != null && planId.isNotEmpty) {
        unawaited(_syncPlanFromApi(planId));
      }
    }

    if (event.type == 'friend_request') {
      _applyFriendRequestNotification(event);
    }

    if (event.notificationId != null) {
      final id = event.notificationId!;
      if (notifications.any((n) => n.id == id)) {
        if (event.type == 'removed_from_plan' ||
            event.type == 'friend_request') {
          notifyListeners();
        }
        return;
      }
      notifications.insert(
        0,
        SquadNotification(
          id: id,
          type: event.type,
          planId: event.planId,
          title: event.title,
          body: event.body,
          read: false,
          createdAt: DateTime.now(),
          hostId: event.hostId,
          hostName: event.hostName,
          planTitle: event.planTitle,
          requesterId: event.requesterId,
          requesterName: event.requesterName,
        ),
      );
      notifyListeners();
      return;
    }
    unawaited(ApiLoading.runSilently(refreshNotifications));
  }

  void _applyFriendRequestNotification(InboxNotificationHubEvent event) {
    final requesterId = event.requesterId;
    if (requesterId != null && requesterId.isNotEmpty) {
      incomingRequestIds.add(requesterId);
      unawaited(users.prefetch([requesterId]));
    }
    unawaited(ApiLoading.runSilently(refreshFriendsFromApi));
  }

  void clearRemovedFromPlanToast() {
    if (removedFromPlanToast == null) return;
    removedFromPlanToast = null;
    removedFromPlanToastPlanId = null;
    notifyListeners();
  }

  void clearPlanCancelledToast() {
    if (planCancelledToast == null) return;
    planCancelledToast = null;
    planCancelledToastPlanId = null;
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (!isAuthenticated) return;
    try {
      notifications = await _notificationService.fetch(limit: 50);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Notifications failed: $e';
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final updated = await _notificationService.markRead(notificationId);
    if (updated == null) return;
    final i = notifications.indexWhere((n) => n.id == notificationId);
    if (i >= 0) {
      notifications[i] = updated;
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    await _notificationService.markAllRead();
    notifications = notifications
        .map(
          (n) => SquadNotification(
            id: n.id,
            type: n.type,
            planId: n.planId,
            title: n.title,
            body: n.body,
            read: true,
            createdAt: n.createdAt,
            hostId: n.hostId,
            hostName: n.hostName,
            planTitle: n.planTitle,
          ),
        )
        .toList();
    notifyListeners();
  }

  /// Clears the inbox locally (layout `clearNotifications`). Items may reappear on refresh until a delete API exists.
  Future<void> clearAllNotifications() async {
    await markAllNotificationsRead();
    notifications = [];
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
  final List<SquadPlan> recapPlans = [];
  bool recapPlansLoading = false;
  String? recapPlansError;
  final Set<String> cancelledPlanIds = {};
  final Set<String> incomingRequestIds = {};
  final Set<String> outgoingRequestIds = {};

  static const int feedPageSize = 10;

  bool feedLoading = false;
  bool feedLoadingMore = false;
  bool feedHasMore = true;
  int _feedNextOffset = 0;

  SquadPlan? tryPlanById(String id) {
    SquadPlan? best;
    for (final p in [...recentPlans, ...recapPlans, ...plans]) {
      if (p.id != id) continue;
      if (best == null || p.photos.length > best.photos.length) {
        best = p;
      }
    }
    return best;
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

  List<SquadUser> suggestedFriends = [];
  bool suggestedFriendsLoading = false;
  int _suggestedSeed = 0;

  /// Loads up to [limit] users for the Suggested tab (does not send friend requests).
  Future<void> loadSuggestedFriends({bool reload = false, int limit = 10}) async {
    if (reload) _suggestedSeed += 1;
    suggestedFriendsLoading = true;
    notifyListeners();
    try {
      final payload = await _friendRepo.fetchSuggested(
        limit: limit,
        seed: _suggestedSeed,
      );
      users.seedProfiles(payload.profiles);
      await users.prefetch(payload.ids);
      suggestedFriends = listUsersForIds(payload.ids);
      apiProbeMessage = null;
    } catch (e) {
      suggestedFriends = [];
      apiProbeMessage = 'Suggested friends failed: $e';
    } finally {
      suggestedFriendsLoading = false;
      notifyListeners();
    }
  }

  List<SquadPlan> friendFeed() {
    final uid = currentUser?.id;
    if (uid == null) return [];
    bool visible(SquadPlan p) {
      if (cancelledPlanIds.contains(p.id)) return false;
      if (p.hasStarted) return false;
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

  /// Label for filter chips and plan badges (catalog, then AI cache).
  String vibeLabelForEmoji(String emoji) {
    final e = emoji.trim();
    final catalog = squadVibeFromEmoji(e);
    if (catalog != null) return kVibeMeta[catalog]!.label;
    final ai = vibeEmojiLabels[e];
    if (ai != null && ai.isNotEmpty) return ai;
    return '';
  }

  Future<void> refreshVibeLabelsForCurrentFeed() async {
    final emojis = vibeEmojisFromPlans(
      mergeFeedPlansForFilter(
        recent: feedRecentPlans(),
        squad: feedSquadPlans(),
      ),
    );
    final missing = emojis.where((e) {
      if (squadVibeFromEmoji(e) != null) return false;
      return !vibeEmojiLabels.containsKey(e);
    }).toList();
    if (missing.isEmpty) return;
    try {
      final labels = await ApiLoading.runSilently(
        () => _planRepo.fetchVibeLabels(missing),
      );
      vibeEmojiLabels.addAll(labels);
      notifyListeners();
    } catch (_) {
      // Chips still show emoji-only when AI unavailable.
    }
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

  bool canEditPlan(SquadPlan plan) =>
      isHost(plan) && !isPlanCancelled(plan.id) && !plan.hasStarted;

  /// All plans from feed stores, deduped by id — `squadUp-layout` `my-plans.tsx`.
  List<SquadPlan> allPlansMerged() {
    final seen = <String>{};
    final out = <SquadPlan>[];
    for (final p in [...recentPlans, ...plans]) {
      if (seen.add(p.id)) out.add(p);
    }
    return out;
  }

  /// Plan start time has passed — belongs on Recaps, not My Plans.
  bool isPlanStarted(SquadPlan plan) => plan.hasStarted;

  /// Upcoming plan — belongs on My Plans, not Recaps.
  bool isPlanNotStarted(SquadPlan plan) =>
      !isPlanStarted(plan) && !isPlanCancelled(plan.id);

  bool isUserAttending(SquadPlan plan, String userId) =>
      plan.creatorId == userId || plan.userHasTappedIn(userId);

  /// My Plans → Attended tab: tapped-in guest plans that have not started.
  List<SquadPlan> myPlansUpcoming(String userId) {
    return allPlansMerged()
        .where(
          (p) =>
              isPlanNotStarted(p) &&
              isUserAttending(p, userId) &&
              p.creatorId != userId,
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  /// My Plans → Hosting tab: your hosted plans that have not started.
  List<SquadPlan> myPlansHosting(String userId) {
    return allPlansMerged()
        .where(
          (p) => p.creatorId == userId && isPlanNotStarted(p),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  /// Spots copy for host cards — layout `spotsLeft` / unlimited.
  String planSpotsLabel(SquadPlan plan) {
    if (plan.threshold >= 99) return 'Unlimited';
    final left = (plan.threshold - plan.tapInCount).clamp(0, plan.threshold);
    return '$left left';
  }

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

  Future<void> refreshPlanDetail(String planId) async {
    try {
      final remote = await _planRepo.getPlan(planId);
      if (remote == null) return;
      if (tryPlanById(planId) != null) {
        _replacePlan(remote);
      } else {
        plans.insert(0, remote);
        recentPlans.insert(0, remote);
      }
      await users.prefetch([remote.creatorId, ...remote.tapInUserIds]);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Load plan failed: $e';
      notifyListeners();
    }
  }

  Future<SquadPlan?> addPlanFromDraft(
    PlanDraft draft,
    PlanSource source, {
    List<XFile> localPhotos = const [],
  }) async {
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
    if (acts.isEmpty) return null;

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
      if (localPhotos.isNotEmpty) {
        final photoCount = localPhotos.length.clamp(
          0,
          PlanPhotoService.maxHostInitialPhotos,
        );
        try {
          await _uploadPlanPhotosWithProgress(
            plan.id,
            localPhotos,
            maxCount: PlanPhotoService.maxHostInitialPhotos,
          );
          planPhotoUploadProgress = PlanPhotoUploadProgress(
            planId: plan.id,
            completed: photoCount,
            total: photoCount,
            syncing: true,
          );
          notifyListeners();
          plan = await _planRepo.getPlan(plan.id) ?? plan;
        } finally {
          planPhotoUploadProgress = null;
          notifyListeners();
        }
      } else {
        plan = await _planRepo.getPlan(plan.id) ?? plan;
      }
      recentPlans.insert(0, plan);
      final existing = plans.indexWhere((p) => p.id == plan.id);
      if (existing >= 0) {
        plans[existing] = plan;
      } else {
        plans.insert(0, plan);
      }
      await users.prefetch([plan.creatorId, ...plan.tapInUserIds]);
      notifyListeners();
      return plan;
    } catch (e) {
      apiProbeMessage = 'Create plan failed: $e';
      notifyListeners();
      return null;
    }
  }

  Future<SquadPlan?> updatePlanFromDraft(String planId, PlanDraft draft) async {
    final existing = _findPlan(planId);
    if (existing == null || !canEditPlan(existing)) return null;
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
    if (acts.isEmpty) return null;

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
        visibility: draft.visibility,
      );
      final plan = await _planRepo.updatePlan(planId, apiDraft);
      _replacePlan(plan);
      notifyListeners();
      return plan;
    } catch (e) {
      apiProbeMessage = 'Update plan failed: $e';
      notifyListeners();
      return null;
    }
  }

  SquadPlan? _findPlan(String planId) => tryPlanById(planId);

  /// Keeps gallery URLs when a feed/hub payload omits `photos` (common on `planCreated`).
  SquadPlan _mergePlanPreservePhotos(SquadPlan incoming, SquadPlan? existing) {
    if (existing != null &&
        incoming.photos.isEmpty &&
        existing.photos.isNotEmpty) {
      return SquadPlan(
        id: incoming.id,
        creatorId: incoming.creatorId,
        vibeEmoji: incoming.vibeEmoji,
        title: incoming.title,
        startAt: incoming.startAt,
        threshold: incoming.threshold,
        status: incoming.status,
        source: incoming.source,
        description: incoming.description,
        activities: incoming.activities,
        gameName: incoming.gameName,
        location: incoming.location,
        transcript: incoming.transcript,
        tapInUserIds: incoming.tapInUserIds,
        createdAt: incoming.createdAt,
        visibility: incoming.visibility,
        photos: existing.photos,
        sharedToProfile: incoming.sharedToProfile,
        recapRole: incoming.recapRole,
      );
    }
    return incoming;
  }

  void _replacePlan(SquadPlan updated) {
    final merged = _mergePlanPreservePhotos(updated, tryPlanById(updated.id));
    for (var i = 0; i < recentPlans.length; i++) {
      if (recentPlans[i].id == merged.id) recentPlans[i] = merged;
    }
    for (var i = 0; i < plans.length; i++) {
      if (plans[i].id == merged.id) plans[i] = merged;
    }
    for (var i = 0; i < recapPlans.length; i++) {
      if (recapPlans[i].id == merged.id) recapPlans[i] = merged;
    }
  }

  Future<void> _syncPlanFromApi(String planId) async {
    await ApiLoading.runSilently(() async {
      final remote = await _planRepo.getPlan(planId);
      if (remote == null) return;
      _replacePlan(remote);
      await users.prefetch([remote.creatorId, ...remote.tapInUserIds]);
    });
  }

  bool canUploadPlanPhotos(SquadPlan plan) {
    final uid = currentUser?.id;
    if (uid == null) return false;
    if (isPlanCancelled(plan.id)) return false;
    if (!plan.hasStarted) return false;
    return isHost(plan) || plan.userHasTappedIn(uid);
  }

  Future<void> uploadPlanPhotos(String planId, List<XFile> files) async {
    if (files.isEmpty) return;
    try {
      await _uploadPlanPhotosWithProgress(planId, files);
      planPhotoUploadProgress = PlanPhotoUploadProgress(
        planId: planId,
        completed: files.length,
        total: files.length,
        syncing: true,
      );
      notifyListeners();
      await _syncPlanFromApi(planId);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Upload photos failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      planPhotoUploadProgress = null;
      notifyListeners();
    }
  }

  Future<void> _uploadPlanPhotosWithProgress(
    String planId,
    List<XFile> files, {
    int? maxCount,
  }) async {
    final slice = (maxCount != null ? files.take(maxCount) : files).toList();
    if (slice.isEmpty) return;

    void setProgress({required int completed, required bool syncing}) {
      planPhotoUploadProgress = PlanPhotoUploadProgress(
        planId: planId,
        completed: completed,
        total: slice.length,
        syncing: syncing,
      );
      notifyListeners();
    }

    setProgress(completed: 0, syncing: false);
    await _planPhotos.uploadPlanPhotos(
      planId,
      slice,
      onProgress: (completed, total) {
        setProgress(completed: completed, syncing: false);
      },
    );
  }

  Future<void> removePlanPhoto(String planId, String photoId) async {
    try {
      await _planPhotos.deletePlanPhoto(planId, photoId);
      await _syncPlanFromApi(planId);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Remove photo failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<TapInOutcome?> tapIn(String planId) async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final plan = _findPlan(planId);
    if (plan == null) return null;
    if (plan.status != PlanStatus.active) return null;
    if (plan.hasStarted) return null;
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

  Future<void> removeAttendee(String planId, String attendeeId) async {
    final uid = currentUser?.id;
    if (uid == null) return;

    final plan = _findPlan(planId);
    if (plan == null || !isHost(plan) || isPlanCancelled(planId)) {
      return;
    }
    if (attendeeId == plan.creatorId) return;
    try {
      await _planRepo.removeAttendee(planId, attendeeId);
      await _syncPlanFromApi(planId);
      notifyListeners();
    } catch (e) {
      apiProbeMessage = 'Remove attendee failed: $e';
      notifyListeners();
      rethrow;
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
      final page = await ApiPlanRepository(client: _apiClient).fetchFeed(
        limit: feedPageSize,
      );
      apiProbeMessage = 'API OK — ${page.plans.length} plan(s) from feed';
      plans
        ..clear()
        ..addAll(page.plans);
      feedHasMore = page.hasMore;
      _feedNextOffset = page.nextOffset;
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
    feedLoading = true;
    feedLoadingMore = false;
    _feedNextOffset = 0;
    feedHasMore = true;
    notifyListeners();
    try {
      final page = await _planRepo.fetchFeed(
        limit: feedPageSize,
        offset: 0,
      );
      plans
        ..clear()
        ..addAll(page.plans);
      feedHasMore = page.hasMore;
      _feedNextOffset = page.nextOffset;
      final ids = <String>{};
      for (final p in page.plans) {
        ids.add(p.creatorId);
        ids.addAll(p.tapInUserIds);
      }
      apiProbeMessage = null;
      await users.prefetch(ids);
      unawaited(refreshVibeLabelsForCurrentFeed());
    } catch (e) {
      apiProbeMessage = 'Feed sync failed: $e';
    } finally {
      feedLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next feed page when the dashboard is scrolled near the end.
  Future<void> loadMoreFeed() async {
    if (feedLoading || feedLoadingMore || !feedHasMore) return;
    feedLoadingMore = true;
    notifyListeners();
    try {
      final page = await ApiLoading.runSilently(
        () => _planRepo.fetchFeed(
          limit: feedPageSize,
          offset: _feedNextOffset,
        ),
      );
      final seen = plans.map((p) => p.id).toSet();
      for (final p in page.plans) {
        if (seen.add(p.id)) plans.add(p);
      }
      feedHasMore = page.hasMore;
      _feedNextOffset = page.nextOffset;
      final ids = <String>{};
      for (final p in page.plans) {
        ids.add(p.creatorId);
        ids.addAll(p.tapInUserIds);
      }
      await users.prefetch(ids);
      unawaited(refreshVibeLabelsForCurrentFeed());
      apiProbeMessage = null;
    } catch (e) {
      apiProbeMessage = 'Feed load more failed: $e';
    } finally {
      feedLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecapsFromApi() async {
    recapPlansLoading = true;
    recapPlansError = null;
    notifyListeners();
    try {
      final list = await _planRepo.fetchRecaps();
      recapPlans
        ..clear()
        ..addAll(list.where(isPlanStarted));
      recapPlansError = null;
    } catch (e) {
      recapPlansError = e.toString();
    } finally {
      recapPlansLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleProfileShare(SquadPlan plan, bool shared) async {
    final updated = await _planRepo.setProfileShare(
      plan.id,
      shared: shared,
    );
    _replacePlan(updated);
    notifyListeners();
  }

  Future<List<SquadPlan>> fetchProfileRecaps(String userId) =>
      _userRepo.fetchProfileRecaps(userId);

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
