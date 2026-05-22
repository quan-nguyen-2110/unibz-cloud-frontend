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

  return SquadPlan(
    id: json['id'] as String,
    creatorId: json['creatorId'] as String,
    vibeEmoji: json['vibeEmoji'] as String? ?? '✨',
    title: json['title'] as String,
    description: json['description'] as String?,
    activities: activities,
    gameName: json['gameName'] as String?,
    location: json['location'] as String?,
    startAt: DateTime.parse(json['startAt'] as String),
    threshold: json['threshold'] as int? ?? 2,
    status: _statusFromJson(json['status'] as String?),
    source: _sourceFromJson(json['source'] as String?),
    transcript: json['transcript'] as String?,
    tapInUserIds: (json['tapInUserIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
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
    };

TapInOutcome tapInOutcomeFromJson(Map<String, dynamic> json) {
  return TapInOutcome(squadLocked: json['squadLocked'] as bool? ?? false);
}

SquadUser squadUserFromJson(Map<String, dynamic> json) {
  final bio = json['bio'] as String?;
  return SquadUser(
    id: json['userId'] as String? ?? json['id'] as String,
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String? ?? 'User',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    avatarEmoji: '\u{1F9D1}',
    bio: bio != null && bio.trim().isNotEmpty ? bio.trim() : null,
  );
}
