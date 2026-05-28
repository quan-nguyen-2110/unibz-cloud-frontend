import 'package:flutter/foundation.dart';

enum PlanStatus { active, locked, completed }

enum PlanSource { manual, voice, suggestion }

/// Who can see a plan — `squadUp-layout` `Plan.visibility`.
enum PlanVisibility { public, private }

/// Whether the current user hosted or attended a recap plan.
enum RecapRole { hosted, attended }

/// One line item inside a plan (a hangout can bundle several stops).
@immutable
class PlanActivity {
  const PlanActivity({
    required this.emoji,
    required this.title,
    this.location,
    this.durationMinutes,
  });

  final String emoji;
  final String title;

  /// Where this specific activity happens; may be null.
  final String? location;

  /// Rough time budget for this stop, in minutes; may be null.
  final int? durationMinutes;

  /// Human-readable time spend, or null.
  String? get durationLabel {
    final m = durationMinutes;
    if (m == null || m <= 0) return null;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    if (r == 0) return '$h h';
    return '$h h $r min';
  }
}

@immutable
class SquadUser {
  const SquadUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.phone,
    required this.city,
    required this.avatarEmoji,
    this.age,
    this.genderLabel,
    this.bio,
    this.interests,
    this.profileLocation,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String phone;
  final String city;
  final String avatarEmoji;

  /// Optional rich profile (layout reference / detail screens).
  final int? age;
  final String? genderLabel;
  final String? bio;
  final List<String>? interests;

  /// Location line on profile; falls back to [city] when absent.
  final String? profileLocation;

  /// Remote avatar image URL from the API; falls back to initials.
  final String? avatarUrl;
}

/// Plan gallery image (API + layout `PlanPhoto`).
@immutable
class PlanPhoto {
  const PlanPhoto({
    required this.id,
    required this.url,
    required this.uploaderId,
    this.createdAt,
  });

  final String id;
  final String url;
  final String uploaderId;
  final DateTime? createdAt;
}

/// Active multi-photo upload for a plan (presign → S3 → confirm).
@immutable
class PlanPhotoUploadProgress {
  const PlanPhotoUploadProgress({
    required this.planId,
    required this.completed,
    required this.total,
    this.syncing = false,
  });

  final String planId;
  final int completed;
  final int total;
  final bool syncing;

  bool get isActive => total > 0;

  String get title {
    if (syncing) return 'Finishing up…';
    if (total <= 1) return 'Uploading photo…';
    return 'Uploading photo $completed of $total…';
  }

  String get subtitle {
    if (syncing) return 'Updating your gallery';
    return 'Sending to secure storage';
  }
}

@immutable
class PlanDraft {
  const PlanDraft({
    required this.vibeEmoji,
    required this.title,
    required this.startAt,
    this.description,
    this.activities = const [],
    this.location,
    this.gameName,
    this.threshold = 2,
    this.transcript,
    this.visibility = PlanVisibility.public,
  });

  final String vibeEmoji;
  final String title;
  final DateTime startAt;

  /// Extra context for friends; may be null.
  final String? description;

  /// When empty, [vibeEmoji] + [title] are treated as a single activity on save.
  final List<PlanActivity> activities;
  final String? location;
  final String? gameName;
  final int threshold;
  final String? transcript;
  final PlanVisibility visibility;

  PlanDraft copyWith({
    String? vibeEmoji,
    String? title,
    DateTime? startAt,
    String? description,
    List<PlanActivity>? activities,
    String? location,
    String? gameName,
    int? threshold,
    String? transcript,
    PlanVisibility? visibility,
  }) {
    return PlanDraft(
      vibeEmoji: vibeEmoji ?? this.vibeEmoji,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      description: description ?? this.description,
      activities: activities ?? this.activities,
      location: location ?? this.location,
      gameName: gameName ?? this.gameName,
      threshold: threshold ?? this.threshold,
      transcript: transcript ?? this.transcript,
      visibility: visibility ?? this.visibility,
    );
  }
}

class SquadPlan {
  SquadPlan({
    required this.id,
    required this.creatorId,
    required this.vibeEmoji,
    required this.title,
    required this.startAt,
    required this.threshold,
    required this.status,
    required this.source,
    this.description,
    List<PlanActivity>? activities,
    this.gameName,
    this.location,
    this.transcript,
    List<String>? tapInUserIds,
    DateTime? createdAt,
    this.visibility = PlanVisibility.public,
    List<PlanPhoto>? photos,
    this.sharedToProfile = false,
    this.recapRole,
  })  : activities = activities ?? const [],
        tapInUserIds = tapInUserIds ?? [],
        photos = photos ?? const [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String creatorId;

  /// Shown large on the card; keep in sync with first activity emoji when possible.
  final String vibeEmoji;
  final String title;
  final String? description;
  final List<PlanActivity> activities;
  final String? gameName;
  final String? location;
  final DateTime startAt;
  final int threshold;
  PlanStatus status;
  final PlanSource source;
  final String? transcript;
  final List<String> tapInUserIds;
  final DateTime createdAt;
  final PlanVisibility visibility;
  final List<PlanPhoto> photos;

  /// Past plan shared to the user's profile (Recaps tab).
  final bool sharedToProfile;

  /// Set on recap/profile-recap responses for the viewing user.
  final RecapRole? recapRole;

  int get tapInCount => tapInUserIds.length;

  bool get hasStarted => !DateTime.now().toUtc().isBefore(startAt.toUtc());

  bool get isPrivate => visibility == PlanVisibility.private;

  bool get isHostedRecap => recapRole == RecapRole.hosted;

  bool userHasTappedIn(String userId) => tapInUserIds.contains(userId);

  /// Effective list for UI (handles legacy plans with empty [activities]).
  List<PlanActivity> get resolvedActivities {
    if (activities.isNotEmpty) return activities;
    final loc = location?.trim();
    return [
      PlanActivity(
        emoji: vibeEmoji,
        title: title,
        location: (loc == null || loc.isEmpty) ? null : loc,
        durationMinutes: null,
      ),
    ];
  }
}

/// Non-null means the join was applied. [squadLocked] is true when threshold was reached.
@immutable
class TapInOutcome {
  const TapInOutcome({required this.squadLocked});

  final bool squadLocked;
}

/// In-app inbox item (e.g. host cancelled a plan you joined).
@immutable
class SquadNotification {
  const SquadNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.planId,
    this.hostId,
    this.hostName,
    this.planTitle,
    this.requesterId,
    this.requesterName,
  });

  final String id;
  final String type;
  final String? planId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? hostId;
  final String? hostName;
  final String? planTitle;
  final String? requesterId;
  final String? requesterName;

  bool get isPlanCancelled => type == 'plan_cancelled';

  bool get isPlanReminder => type == 'plan_reminder';

  bool get isFriendRequest => type == 'friend_request';

  bool get isNewAttendee => type == 'new_attendee';

  bool get isAttendeeLeft => type == 'attendee_left';

  bool get isRemovedFromPlan => type == 'removed_from_plan';
}

/// Feed-wide realtime event from `/hub/feed` broadcasts (plan tap-in, lock, etc.).
enum FeedPlanHubKind { created, tapIn, tapOut, locked, updated }

@immutable
class FeedPlanHubEvent {
  const FeedPlanHubEvent._({
    required this.kind,
    this.plan,
    this.planId,
    this.userId,
    this.tapInCount,
  });

  const FeedPlanHubEvent.created(SquadPlan plan)
      : this._(kind: FeedPlanHubKind.created, plan: plan);

  const FeedPlanHubEvent.updated(SquadPlan plan)
      : this._(kind: FeedPlanHubKind.updated, plan: plan);

  const FeedPlanHubEvent.tapIn({
    required String planId,
    required String userId,
    int? tapInCount,
  }) : this._(
          kind: FeedPlanHubKind.tapIn,
          planId: planId,
          userId: userId,
          tapInCount: tapInCount,
        );

  const FeedPlanHubEvent.tapOut({
    required String planId,
    required String userId,
  }) : this._(
          kind: FeedPlanHubKind.tapOut,
          planId: planId,
          userId: userId,
        );

  const FeedPlanHubEvent.locked({
    required String planId,
    int? tapInCount,
  }) : this._(
          kind: FeedPlanHubKind.locked,
          planId: planId,
          tapInCount: tapInCount,
        );

  final FeedPlanHubKind kind;
  final SquadPlan? plan;
  final String? planId;
  final String? userId;
  final int? tapInCount;
}

/// Realtime inbox payload from `/hub/feed` (planCancelled, newAttendee, attendeeLeft).
@immutable
class InboxNotificationHubEvent {
  const InboxNotificationHubEvent({
    required this.type,
    required this.title,
    required this.body,
    this.notificationId,
    this.planId,
    this.hostId,
    this.hostName,
    this.planTitle,
    this.attendeeId,
    this.attendeeName,
    this.requesterId,
    this.requesterName,
  });

  final String type;
  final String title;
  final String body;
  final String? notificationId;
  final String? planId;
  final String? hostId;
  final String? hostName;
  final String? planTitle;
  final String? attendeeId;
  final String? attendeeName;
  final String? requesterId;
  final String? requesterName;

  bool get isPlanCancelled => type == 'plan_cancelled';
}

/// Realtime payload from `/hub/feed` `planCancelled` event.
@immutable
class PlanCancelledHubEvent {
  const PlanCancelledHubEvent({
    required this.planId,
    required this.message,
    this.notificationId,
    this.hostId,
    this.hostName,
    this.planTitle,
  });

  final String planId;
  final String message;
  final String? notificationId;
  final String? hostId;
  final String? hostName;
  final String? planTitle;

  InboxNotificationHubEvent toInboxEvent() {
    return InboxNotificationHubEvent(
      type: 'plan_cancelled',
      title: 'Plan cancelled',
      body: message,
      notificationId: notificationId,
      planId: planId,
      hostId: hostId,
      hostName: hostName,
      planTitle: planTitle,
    );
  }
}
