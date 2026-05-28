import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/squad_theme.dart';

/// Vibe filters matching the SquadUp layout reference.
enum SquadVibe {
  all,
  hoops,
  swim,
  cafe,
  study,
  gaming,
  outdoors,
  movie,
  party,
}

class VibeStyle {
  const VibeStyle({
    required this.label,
    required this.emoji,
    required this.softBg,
    required this.softFg,
  });

  final String label;
  final String emoji;
  final Color softBg;
  final Color softFg;
}

final Map<SquadVibe, VibeStyle> kVibeMeta = {
  SquadVibe.all: VibeStyle(
    label: 'All',
    emoji: '✨',
    softBg: SquadColors.mutedBg,
    softFg: SquadColors.text,
  ),
  SquadVibe.hoops: VibeStyle(
    label: 'Hoops',
    emoji: '🏀',
    softBg: SquadColors.hoopsSoft,
    softFg: SquadColors.hoops,
  ),
  SquadVibe.swim: VibeStyle(
    label: 'Swim',
    emoji: '🏊',
    softBg: SquadColors.swimSoft,
    softFg: SquadColors.swim,
  ),
  SquadVibe.cafe: VibeStyle(
    label: 'Cafe',
    emoji: '☕',
    softBg: SquadColors.cafeSoft,
    softFg: SquadColors.cafe,
  ),
  SquadVibe.study: VibeStyle(
    label: 'Study',
    emoji: '📖',
    softBg: SquadColors.studySoft,
    softFg: SquadColors.study,
  ),
  SquadVibe.gaming: VibeStyle(
    label: 'Gaming',
    emoji: '🎮',
    softBg: SquadColors.gamingSoft,
    softFg: SquadColors.gaming,
  ),
  SquadVibe.outdoors: VibeStyle(
    label: 'Outdoors',
    emoji: '🌳',
    softBg: const Color(0xFFE6F4EA),
    softFg: const Color(0xFF2E7D32),
  ),
  SquadVibe.movie: VibeStyle(
    label: 'Movie',
    emoji: '🎬',
    softBg: const Color(0xFFE8EAF6),
    softFg: const Color(0xFF3949AB),
  ),
  SquadVibe.party: VibeStyle(
    label: 'Party',
    emoji: '🎉',
    softBg: const Color(0xFFFFEBEE),
    softFg: const Color(0xFFC62828),
  ),
};

SquadVibe? squadVibeFromEmoji(String emoji) {
  final e = emoji.trim();
  const map = {
    '🏀': SquadVibe.hoops,
    '🏊': SquadVibe.swim,
    '☕': SquadVibe.cafe,
    '📖': SquadVibe.study,
    '🎮': SquadVibe.gaming,
    '🌳': SquadVibe.outdoors,
    '🎬': SquadVibe.movie,
    '🎉': SquadVibe.party,
  };
  return map[e];
}

SquadVibe? squadVibeForPlan(SquadPlan plan) {
  final fromMain = squadVibeFromEmoji(plan.vibeEmoji);
  if (fromMain != null) return fromMain;
  for (final a in plan.resolvedActivities) {
    final v = squadVibeFromEmoji(a.emoji);
    if (v != null) return v;
  }
  return null;
}

@Deprecated('Use planMatchesVibeEmojiFilter with feed-derived emojis.')
bool planMatchesVibeFilter(SquadPlan plan, SquadVibe filter) {
  if (filter == SquadVibe.all) return true;
  return squadVibeForPlan(plan) == filter;
}

/// Distinct [SquadPlan.vibeEmoji] values present in [plans] (most common first).
List<String> vibeEmojisFromPlans(Iterable<SquadPlan> plans) {
  final counts = <String, int>{};
  for (final plan in plans) {
    final emoji = plan.vibeEmoji.trim();
    if (emoji.isEmpty) continue;
    counts[emoji] = (counts[emoji] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.compareTo(b);
    });
  return keys;
}

/// [selectedEmoji] `null` = show all plans.
bool planMatchesVibeEmojiFilter(SquadPlan plan, String? selectedEmoji) {
  if (selectedEmoji == null) return true;
  return plan.vibeEmoji.trim() == selectedEmoji.trim();
}

VibeStyle vibeStyleForEmoji(String emoji) {
  final mapped = squadVibeFromEmoji(emoji);
  if (mapped != null) return kVibeMeta[mapped]!;
  return VibeStyle(
    label: '',
    emoji: emoji,
    softBg: SquadColors.mutedBg,
    softFg: SquadColors.text,
  );
}

/// Feed + squad sections without duplicate plan ids.
List<SquadPlan> mergeFeedPlansForFilter({
  required List<SquadPlan> recent,
  required List<SquadPlan> squad,
}) {
  final seen = <String>{};
  final out = <SquadPlan>[];
  for (final plan in [...recent, ...squad]) {
    if (seen.add(plan.id)) out.add(plan);
  }
  return out;
}
