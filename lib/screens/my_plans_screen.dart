// Migrated from squadUp-layout/src/routes/my-plans.tsx (ceb66d0).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';
import 'plan_detail_screen.dart';

enum _MyPlansTab { attended, hosting }

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({
    super.key,
    this.onSwitchToHome,
    this.onSwitchToCreate,
  });

  final VoidCallback? onSwitchToHome;
  final VoidCallback? onSwitchToCreate;

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  _MyPlansTab _tab = _MyPlansTab.attended;

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
    return Consumer<AppState>(
      builder: (context, app, _) {
        final uid = app.currentUser?.id;
        if (uid == null) {
          return const Center(child: Text('Sign in to see your plans'));
        }

        final attended = app.myPlansUpcoming(uid);
        final hosting = app.myPlansHosting(uid);

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'My Plans',
                subtitle: "Everything you're in on",
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: _TabBar(
                  tab: _tab,
                  attendedCount: attended.length,
                  hostingCount: hosting.length,
                  onSelect: (t) => setState(() => _tab = t),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  _buildTabBody(context, app, attended, hosting),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildTabBody(
    BuildContext context,
    AppState app,
    List<SquadPlan> attended,
    List<SquadPlan> hosting,
  ) {
    switch (_tab) {
      case _MyPlansTab.attended:
        if (attended.isEmpty) {
          return [
            _EmptyState(
              icon: Icons.event_note_rounded,
              title: 'No upcoming plans',
              body: "Join a plan from the home feed and it'll show up here.",
              ctaLabel: 'Find plans',
              onCta: widget.onSwitchToHome,
            ),
          ];
        }
        return attended
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GuestPlanCard(
                  plan: p,
                  nameFor: app.displayNameFor,
                  timeLabel: _formatPlanTime(p.startAt),
                  past: false,
                ),
              ),
            )
            .toList();
      case _MyPlansTab.hosting:
        if (hosting.isEmpty) {
          return [
            _EmptyState(
              icon: Icons.add_rounded,
              title: "You're not hosting anything",
              body: 'Create a plan and your squad can join in seconds.',
              ctaLabel: 'Create plan',
              onCta: widget.onSwitchToCreate,
            ),
          ];
        }
        return hosting
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _HostPlanCard(
                  plan: p,
                  app: app,
                  timeLabel: _formatPlanTime(p.startAt),
                  nameFor: app.displayNameFor,
                ),
              ),
            )
            .toList();
    }
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tab,
    required this.attendedCount,
    required this.hostingCount,
    required this.onSelect,
  });

  final _MyPlansTab tab;
  final int attendedCount;
  final int hostingCount;
  final ValueChanged<_MyPlansTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SquadColors.mutedBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TabChip(
            label: 'Attended',
            count: attendedCount,
            active: tab == _MyPlansTab.attended,
            countStyle: _TabCountStyle.muted,
            onTap: () => onSelect(_MyPlansTab.attended),
          ),
          _TabChip(
            label: 'Hosting',
            count: hostingCount,
            active: tab == _MyPlansTab.hosting,
            countStyle: _TabCountStyle.primary,
            onTap: () => onSelect(_MyPlansTab.hosting),
          ),
        ],
      ),
    );
  }
}

enum _TabCountStyle { primary, muted }

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.active,
    required this.countStyle,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final _TabCountStyle countStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? SquadColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: SquadColors.cardShadow,
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? SquadColors.text : SquadColors.muted,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: countStyle == _TabCountStyle.primary
                          ? SquadColors.primary
                          : SquadColors.muted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: countStyle == _TabCountStyle.primary
                            ? Colors.white
                            : SquadColors.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SquadColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SquadColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: SquadColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: squadDisplay(context, 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 14, color: SquadColors.muted),
            textAlign: TextAlign.center,
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                backgroundColor: SquadColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: const StadiumBorder(),
              ),
              child: Text(
                ctaLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestPlanCard extends StatelessWidget {
  const _GuestPlanCard({
    required this.plan,
    required this.nameFor,
    required this.timeLabel,
    required this.past,
  });

  final SquadPlan plan;
  final String Function(String userId) nameFor;
  final String timeLabel;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final hostName = nameFor(plan.creatorId);
    final vibe = squadVibeForPlan(plan);
    final meta = vibe != null ? kVibeMeta[vibe]! : null;
    final loc = plan.location?.trim();
    final primaryLoc = (loc != null && loc.isNotEmpty)
        ? loc
        : (plan.resolvedActivities.isNotEmpty
            ? plan.resolvedActivities.first.location
            : null);

    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlanDetailScreen(planId: plan.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: SquadColors.cardShadow,
          ),
          child: Opacity(
            opacity: past ? 0.9 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SquadInitialsAvatar(
                      initials: displayInitials(hostName),
                      background: avatarColorForKey(plan.creatorId),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hostName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: SquadColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (past) ...[
                                _AttendedBadge(),
                                if (meta != null) const SizedBox(width: 6),
                              ],
                              if (meta != null) _VibePill(meta: meta),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
                if (primaryLoc != null &&
                    primaryLoc.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_rounded,
                          size: 14, color: SquadColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          primaryLoc.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            color: SquadColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 14, color: SquadColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      '${plan.tapInCount} going',
                      style: TextStyle(
                        fontSize: 12,
                        color: SquadColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HostPlanCard extends StatefulWidget {
  const _HostPlanCard({
    required this.plan,
    required this.app,
    required this.timeLabel,
    required this.nameFor,
  });

  final SquadPlan plan;
  final AppState app;
  final String timeLabel;
  final String Function(String userId) nameFor;

  @override
  State<_HostPlanCard> createState() => _HostPlanCardState();
}

class _HostPlanCardState extends State<_HostPlanCard> {
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final app = widget.app;
    final cancelled = app.isPlanCancelled(plan.id);
    final vibe = squadVibeForPlan(plan);
    final meta = vibe != null ? kVibeMeta[vibe]! : null;
    final loc = plan.location?.trim();
    final primaryLoc = (loc != null && loc.isNotEmpty)
        ? loc
        : (plan.resolvedActivities.isNotEmpty
            ? plan.resolvedActivities.first.location
            : null);

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SquadColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: SquadColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SquadColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'HOSTING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: SquadColors.primary,
                    ),
                  ),
                ),
                _PrivacyBadge(isPrivate: plan.isPrivate),
                if (meta != null) _VibePill(meta: meta),
                if (cancelled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SquadColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 12, color: SquadColors.danger),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelled',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: SquadColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlanDetailScreen(planId: plan.id),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: squadDisplay(context, 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.timeLabel,
                    style: TextStyle(fontSize: 12, color: SquadColors.muted),
                  ),
                  if (primaryLoc != null &&
                      primaryLoc.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.place_rounded,
                            size: 14, color: SquadColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            primaryLoc.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: SquadColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TapInAvatars(
                  userIds: plan.tapInUserIds,
                  nameFor: widget.nameFor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${plan.tapInCount} going · ${app.planSpotsLabel(plan)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: SquadColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (!cancelled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PlanDetailScreen(planId: plan.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Manage'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SquadColors.text,
                        backgroundColor: SquadColors.mutedBg,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showCancelDialog(context),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: SquadColors.danger),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          color: SquadColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            SquadColors.danger.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final plan = widget.plan;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancel this plan?'),
        content: Text(
          'Everyone going to "${plan.title}" will be notified. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: SquadColors.danger,
            ),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await widget.app.cancelPlan(plan.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan cancelled. "${plan.title}" was called off.')),
      );
    }
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.isPrivate});

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

class _VibePill extends StatelessWidget {
  const _VibePill({required this.meta});

  final VibeStyle meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: meta.softBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${meta.emoji} ${meta.label}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: meta.softFg,
        ),
      ),
    );
  }
}

class _AttendedBadge extends StatelessWidget {
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
          Icon(Icons.check_circle_outline_rounded,
              size: 12, color: SquadColors.muted),
          const SizedBox(width: 4),
          Text(
            'Attended',
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

class _TapInAvatars extends StatelessWidget {
  const _TapInAvatars({required this.userIds, required this.nameFor});

  final List<String> userIds;
  final String Function(String userId) nameFor;

  @override
  Widget build(BuildContext context) {
    const maxShown = 4;
    final shown = userIds.take(maxShown).toList();
    final extra = userIds.length > maxShown ? userIds.length - maxShown : 0;
    return SizedBox(
      height: 32,
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
