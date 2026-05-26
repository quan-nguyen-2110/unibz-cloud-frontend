import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../theme/squad_theme.dart';
import '../widgets/leave_plan_confirm_dialog.dart';
import '../widgets/squad_layout_widgets.dart';

class PlanCardWidget extends StatelessWidget {
  const PlanCardWidget({
    super.key,
    required this.plan,
    required this.currentUserId,
    required this.onTapIn,
    required this.onTapOut,
    required this.nameFor,
    required this.onLocked,
    this.onLongPressCreator,
    this.onOpenDetail,
  });

  final SquadPlan plan;
  final String? currentUserId;
  final Future<TapInOutcome?> Function() onTapIn;
  final Future<void> Function() onTapOut;
  final String Function(String userId) nameFor;
  final VoidCallback onLocked;
  final void Function(String userId)? onLongPressCreator;
  final VoidCallback? onOpenDetail;

  static String _formatPlanTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(t.year, t.month, t.day);
    final clock = DateFormat('h:mm a');
    if (planDay == today) {
      return 'Today, ${clock.format(t)}';
    }
    if (planDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${clock.format(t)}';
    }
    return '${DateFormat.MMMd().format(t)}, ${clock.format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final creatorName = nameFor(plan.creatorId);
    final hostName =
        plan.creatorId == currentUserId ? 'You' : creatorName;
    final hostInitials = plan.creatorId == currentUserId
        ? displayInitials(creatorName == 'User' ? 'You' : creatorName)
        : displayInitials(creatorName);
    final hostColor = avatarColorForKey(plan.creatorId);

    final acts = plan.resolvedActivities;
    final planLoc = plan.location?.trim();
    final primaryLoc = (planLoc != null && planLoc.isNotEmpty)
        ? planLoc
        : (acts.length == 1 &&
                acts.first.location != null &&
                acts.first.location!.trim().isNotEmpty)
            ? acts.first.location!.trim()
            : null;

    final locked = plan.status == PlanStatus.locked;
    final uid = currentUserId;
    final joined = uid != null && plan.userHasTappedIn(uid);
    final canJoin = plan.status == PlanStatus.active && uid != null && !joined;

    final vibe = squadVibeForPlan(plan);
    final vibeMeta = vibe != null ? kVibeMeta[vibe]! : null;
    final spotsOpen = locked ? 0 : (plan.threshold - plan.tapInCount).clamp(0, plan.threshold);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: SquadColors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: SquadColors.cardShadow,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenDetail,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onLongPress: onLongPressCreator != null
                                ? () => onLongPressCreator!(plan.creatorId)
                                : null,
                            child: SquadInitialsAvatar(
                              initials: hostInitials,
                              background: hostColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hostName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatPlanTime(plan.startAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: SquadColors.muted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _PlanVisibilityBadge(
                                          isPrivate: plan.isPrivate,
                                        ),
                                        if (vibeMeta != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: vibeMeta.softBg,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${vibeMeta.emoji} ${vibeMeta.label}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: vibeMeta.softFg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (plan.description != null &&
                          plan.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          plan.description!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: SquadColors.muted,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (primaryLoc != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              '📍',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                primaryLoc,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: SquadColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (acts.length > 1) ...[
                        const SizedBox(height: 8),
                        Text(
                          acts
                                  .skip(1)
                                  .take(3)
                                  .map((a) => '${a.emoji} ${a.title}')
                                  .join(' · ') +
                              (acts.length > 4
                                  ? ' · +${acts.length - 4} more'
                                  : ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: SquadColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _TapInStack(userIds: plan.tapInUserIds, nameFor: nameFor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locked
                            ? 'Squad locked'
                            : '$spotsOpen spot${spotsOpen == 1 ? '' : 's'} left',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SquadColors.muted,
                        ),
                      ),
                    ),
                    if (locked)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.lock_rounded, color: SquadColors.secondary, size: 20),
                      ),
                    _DownButton(
                      planTitle: plan.title,
                      locked: locked,
                      joined: joined,
                      canJoin: canJoin,
                      onTapIn: onTapIn,
                      onTapOut: onTapOut,
                      onLocked: onLocked,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Public / Friends badge — `squadUp-layout` `index.tsx` (ec99d70).
class _PlanVisibilityBadge extends StatelessWidget {
  const _PlanVisibilityBadge({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SquadColors.mutedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            size: 12,
            color: SquadColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            isPrivate ? 'Friends' : 'Public',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: SquadColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TapInStack extends StatelessWidget {
  const _TapInStack({required this.userIds, required this.nameFor});

  final List<String> userIds;
  final String Function(String userId) nameFor;

  @override
  Widget build(BuildContext context) {
    if (userIds.isEmpty) {
      return Text(
        'Be first',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SquadColors.muted.withValues(alpha: 0.9),
        ),
      );
    }
    const maxShown = 4;
    final shown = userIds.take(maxShown).toList();
    final extra = userIds.length > maxShown ? userIds.length - maxShown : 0;
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++)
            Transform.translate(
              offset: Offset(-8.0 * i, 0),
              child: SquadInitialsAvatar(
                initials: displayInitials(nameFor(shown[i])),
                background: avatarColorForKey(shown[i]),
                size: 32,
              ),
            ),
          if (extra > 0)
            Transform.translate(
              offset: Offset(-8.0 * shown.length, 0),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SquadColors.mutedBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: SquadColors.card, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DownButton extends StatelessWidget {
  const _DownButton({
    required this.planTitle,
    required this.locked,
    required this.joined,
    required this.canJoin,
    required this.onTapIn,
    required this.onTapOut,
    required this.onLocked,
  });

  final String planTitle;
  final bool locked;
  final bool joined;
  final bool canJoin;
  final Future<TapInOutcome?> Function() onTapIn;
  final Future<void> Function() onTapOut;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: SquadColors.mutedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SquadColors.border),
        ),
        child: const Text(
          'Locked',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      );
    }
    if (joined) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          showLeavePlanConfirmDialog(
            context: context,
            planTitle: planTitle,
            onConfirmLeave: onTapOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: SquadColors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: SquadColors.primaryGlowShadow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Going',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.check_rounded, size: 18, color: Colors.white),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: canJoin
          ? () async {
              HapticFeedback.lightImpact();
              final o = await onTapIn();
              if (o?.squadLocked == true) {
                HapticFeedback.mediumImpact();
                onLocked();
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: canJoin ? SquadColors.card : SquadColors.mutedBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SquadColors.border),
          boxShadow: null,
        ),
        child: Text(
          "I'm down",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: canJoin ? SquadColors.text : SquadColors.muted,
          ),
        ),
      ),
    );
  }
}
