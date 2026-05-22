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
};

SquadVibe? squadVibeFromEmoji(String emoji) {
  final e = emoji.trim();
  const map = {
    '🏀': SquadVibe.hoops,
    '🏊': SquadVibe.swim,
    '☕': SquadVibe.cafe,
    '📖': SquadVibe.study,
    '🎮': SquadVibe.gaming,
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

bool planMatchesVibeFilter(SquadPlan plan, SquadVibe filter) {
  if (filter == SquadVibe.all) return true;
  return squadVibeForPlan(plan) == filter;
}
