import 'package:flutter/foundation.dart';

enum PlanStatus { active, locked, completed }

enum PlanSource { manual, voice, suggestion }

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
  })  : activities = activities ?? const [],
        tapInUserIds = tapInUserIds ?? [],
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

  int get tapInCount => tapInUserIds.length;

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
