import '../services/app_datetime.dart';
import 'models.dart';

PlanStatus _statusFromJson(String? raw) {
  switch (raw) {
    case 'locked':
      return PlanStatus.locked;
    case 'completed':
      return PlanStatus.completed;
    default:
      return PlanStatus.active;
  }
}

PlanSource _sourceFromJson(String? raw) {
  switch (raw) {
    case 'voice':
      return PlanSource.voice;
    case 'suggestion':
      return PlanSource.suggestion;
    default:
      return PlanSource.manual;
  }
}

PlanVisibility _visibilityFromJson(String? raw) {
  if (raw == 'private') return PlanVisibility.private;
  return PlanVisibility.public;
}

RecapRole? _recapRoleFromJson(String? raw) {
  switch (raw) {
    case 'hosted':
      return RecapRole.hosted;
    case 'attended':
      return RecapRole.attended;
    default:
      return null;
  }
}

String _visibilityToJson(PlanVisibility v) =>
    v == PlanVisibility.private ? 'private' : 'public';

String _sourceToJson(PlanSource source) {
  switch (source) {
    case PlanSource.voice:
      return 'voice';
    case PlanSource.suggestion:
      return 'suggestion';
    case PlanSource.manual:
      return 'manual';
  }
}

PlanActivity planActivityFromJson(Map<String, dynamic> json) {
  return PlanActivity(
    emoji: json['emoji'] as String? ?? '✨',
    title: json['title'] as String? ?? '',
    location: json['location'] as String?,
    durationMinutes: json['durationMinutes'] as int?,
  );
}

PlanPhoto planPhotoFromJson(Map<String, dynamic> json) {
  final created = json['createdAt'] as String?;
  return PlanPhoto(
    id: json['id'] as String,
    url: json['url'] as String,
    uploaderId: json['uploaderId'] as String,
    createdAt: created != null ? AppDateTime.parseApi(created) : null,
  );
}

Map<String, dynamic> planActivityToJson(PlanActivity a) => {
      'emoji': a.emoji,
      'title': a.title,
      if (a.location != null) 'location': a.location,
      if (a.durationMinutes != null) 'durationMinutes': a.durationMinutes,
    };

SquadPlan squadPlanFromJson(Map<String, dynamic> json) {
  final activities = (json['activities'] as List<dynamic>? ?? [])
      .map((e) => planActivityFromJson(e as Map<String, dynamic>))
      .toList();

  final photos = (json['photos'] as List<dynamic>? ?? [])
      .map((e) => planPhotoFromJson(e as Map<String, dynamic>))
      .toList();

  return SquadPlan(
    id: json['id'] as String,
    creatorId: json['creatorId'] as String,
    vibeEmoji: json['vibeEmoji'] as String? ?? '✨',
    title: json['title'] as String,
    description: json['description'] as String?,
    activities: activities,
    gameName: json['gameName'] as String?,
    location: json['location'] as String?,
    startAt: AppDateTime.parseApi(json['startAt'] as String),
    threshold: json['threshold'] as int? ?? 2,
    status: _statusFromJson(json['status'] as String?),
    source: _sourceFromJson(json['source'] as String?),
    transcript: json['transcript'] as String?,
    tapInUserIds: (json['tapInUserIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    createdAt: json['createdAt'] != null
        ? AppDateTime.parseApi(json['createdAt'] as String)
        : DateTime.now(),
    visibility: _visibilityFromJson(json['visibility'] as String?),
    photos: photos,
    sharedToProfile: json['sharedToProfile'] as bool? ?? false,
    recapRole: _recapRoleFromJson(json['recapRole'] as String?),
  );
}

Map<String, dynamic> planDraftToJson(PlanDraft draft, PlanSource source) => {
      'vibeEmoji': draft.vibeEmoji,
      'title': draft.title,
      'startAt': draft.startAt.toUtc().toIso8601String(),
      'threshold': draft.threshold,
      if (draft.description != null) 'description': draft.description,
      'activities': draft.activities.map(planActivityToJson).toList(),
      if (draft.location != null) 'location': draft.location,
      if (draft.gameName != null) 'gameName': draft.gameName,
      if (draft.transcript != null) 'transcript': draft.transcript,
      'source': _sourceToJson(source),
      'visibility': _visibilityToJson(draft.visibility),
    };

TapInOutcome tapInOutcomeFromJson(Map<String, dynamic> json) {
  return TapInOutcome(squadLocked: json['squadLocked'] as bool? ?? false);
}

SquadNotification squadNotificationFromJson(Map<String, dynamic> json) {
  final metadata = json['metadata'];
  Map<String, dynamic>? meta;
  if (metadata is Map<String, dynamic>) {
    meta = metadata;
  } else if (metadata is Map) {
    meta = Map<String, dynamic>.from(metadata);
  }
  return SquadNotification(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? 'unknown',
    planId: json['planId'] as String?,
    title: json['title'] as String? ?? 'Notification',
    body: json['body'] as String? ?? '',
    read: json['read'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? AppDateTime.parseApi(json['createdAt'] as String)
        : DateTime.now(),
    hostId: meta?['hostId'] as String?,
    hostName: meta?['hostName'] as String?,
    planTitle: meta?['planTitle'] as String?,
    requesterId: meta?['requesterId'] as String?,
    requesterName: meta?['requesterName'] as String?,
  );
}

FeedPlanHubEvent? feedPlanHubEventFromJson(
  String target,
  Map<String, dynamic> json,
) {
  switch (target) {
    case 'planCreated':
      final raw = json['plan'];
      if (raw is! Map) return null;
      return FeedPlanHubEvent.created(
        squadPlanFromJson(Map<String, dynamic>.from(raw)),
      );
    case 'planUpdated':
      final raw = json['plan'];
      if (raw is! Map) return null;
      return FeedPlanHubEvent.updated(
        squadPlanFromJson(Map<String, dynamic>.from(raw)),
      );
    case 'planTapIn':
      final planId = json['planId'] as String?;
      final userId = json['userId'] as String?;
      if (planId == null || planId.isEmpty || userId == null || userId.isEmpty) {
        return null;
      }
      return FeedPlanHubEvent.tapIn(
        planId: planId,
        userId: userId,
        tapInCount: json['tapInCount'] as int?,
      );
    case 'planTapOut':
      final planId = json['planId'] as String?;
      final userId = json['userId'] as String?;
      if (planId == null || planId.isEmpty || userId == null || userId.isEmpty) {
        return null;
      }
      return FeedPlanHubEvent.tapOut(planId: planId, userId: userId);
    case 'planLocked':
      final planId = json['planId'] as String?;
      if (planId == null || planId.isEmpty) return null;
      return FeedPlanHubEvent.locked(
        planId: planId,
        tapInCount: json['tapInCount'] as int?,
      );
    default:
      return null;
  }
}

PlanCancelledHubEvent planCancelledHubEventFromJson(
  Map<String, dynamic> json,
) {
  return PlanCancelledHubEvent(
    planId: json['planId'] as String? ?? '',
    message: json['message'] as String? ??
        'A plan you joined was cancelled.',
    notificationId: json['notificationId'] as String?,
    hostId: json['hostId'] as String?,
    hostName: json['hostName'] as String?,
    planTitle: json['planTitle'] as String?,
  );
}

InboxNotificationHubEvent inboxNotificationHubEventFromJson(
  String type, {
  required Map<String, dynamic> json,
}) {
  final message = json['message'] as String? ?? '';
  switch (type) {
    case 'plan_cancelled':
      return planCancelledHubEventFromJson(json).toInboxEvent();
    case 'new_attendee':
      return InboxNotificationHubEvent(
        type: 'new_attendee',
        title: 'Someone joined your plan',
        body: message.isNotEmpty ? message : 'Someone joined your plan.',
        notificationId: json['notificationId'] as String?,
        planId: json['planId'] as String?,
        planTitle: json['planTitle'] as String?,
        attendeeId: json['attendeeId'] as String?,
        attendeeName: json['attendeeName'] as String?,
      );
    case 'attendee_left':
      return InboxNotificationHubEvent(
        type: 'attendee_left',
        title: 'Someone left your plan',
        body: message.isNotEmpty ? message : 'Someone left your plan.',
        notificationId: json['notificationId'] as String?,
        planId: json['planId'] as String?,
        planTitle: json['planTitle'] as String?,
        attendeeId: json['attendeeId'] as String?,
        attendeeName: json['attendeeName'] as String?,
      );
    case 'removed_from_plan':
      return InboxNotificationHubEvent(
        type: 'removed_from_plan',
        title: 'Removed from plan',
        body: message.isNotEmpty ? message : 'You were removed from a plan.',
        notificationId: json['notificationId'] as String?,
        planId: json['planId'] as String?,
        planTitle: json['planTitle'] as String?,
        hostId: json['hostId'] as String?,
        hostName: json['hostName'] as String?,
      );
    case 'friend_request':
      return InboxNotificationHubEvent(
        type: 'friend_request',
        title: 'New friend request',
        body: message.isNotEmpty ? message : 'Someone wants to be friends.',
        notificationId: json['notificationId'] as String?,
        requesterId: json['requesterId'] as String?,
        requesterName: json['requesterName'] as String?,
      );
    default:
      return InboxNotificationHubEvent(
        type: type,
        title: 'Notification',
        body: message,
        notificationId: json['notificationId'] as String?,
        planId: json['planId'] as String?,
      );
  }
}

SquadUser squadUserFromJson(Map<String, dynamic> json) {
  final bio = json['bio'] as String?;
  final avatarUrl = json['avatarUrl'] as String?;
  final id = json['userId'] as String? ?? json['id'] as String?;
  if (id == null || id.isEmpty) {
    throw FormatException('User JSON missing userId: $json');
  }
  return SquadUser(
    id: id,
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'User',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    avatarEmoji: '\u{1F9D1}',
    bio: bio != null && bio.trim().isNotEmpty ? bio.trim() : null,
    avatarUrl: avatarUrl != null && avatarUrl.trim().isNotEmpty ? avatarUrl.trim() : null,
  );
}
