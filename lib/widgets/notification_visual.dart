import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/squad_theme.dart';

/// Icon + tint for inbox rows — mirrors `iconFor()` in
/// `squadUp-layout/src/routes/notifications.tsx` (0e57c36).
class NotificationVisual {
  const NotificationVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  static NotificationVisual forNotification(SquadNotification n) {
    switch (n.type) {
      case 'plan_cancelled':
        return NotificationVisual(
          icon: Icons.calendar_today_outlined,
          background: SquadColors.danger.withValues(alpha: 0.15),
          foreground: SquadColors.danger,
        );
      case 'plan_reminder':
        return NotificationVisual(
          icon: Icons.schedule_rounded,
          background: SquadColors.primary.withValues(alpha: 0.15),
          foreground: SquadColors.primary,
        );
      case 'friend_request':
        return NotificationVisual(
          icon: Icons.person_add_alt_1_rounded,
          background: SquadColors.secondary.withValues(alpha: 0.2),
          foreground: SquadColors.secondary,
        );
      case 'new_attendee':
      case 'attendee_left':
        return NotificationVisual(
          icon: Icons.groups_rounded,
          background: SquadColors.primary.withValues(alpha: 0.15),
          foreground: SquadColors.primary,
        );
      case 'removed_from_plan':
        return NotificationVisual(
          icon: Icons.person_remove_outlined,
          background: SquadColors.danger.withValues(alpha: 0.15),
          foreground: SquadColors.danger,
        );
      default:
        return NotificationVisual(
          icon: Icons.notifications_outlined,
          background: SquadColors.primary.withValues(alpha: 0.15),
          foreground: SquadColors.primary,
        );
    }
  }
}
