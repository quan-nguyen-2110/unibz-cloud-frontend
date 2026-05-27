// Migrated from squadUp-layout/src/routes/recaps.tsx (layout 22a7a55).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';
import 'plan_detail_screen.dart';

class RecapsScreen extends StatefulWidget {
  const RecapsScreen({super.key});

  @override
  State<RecapsScreen> createState() => _RecapsScreenState();
}

class _RecapsScreenState extends State<RecapsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshRecapsFromApi();
    });
  }

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
        if (app.recapPlansLoading && app.recapPlans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Recaps',
                subtitle: "Plans you've attended or hosted",
              ),
            ),
            if (app.recapPlansError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    app.recapPlansError!,
                    style: TextStyle(color: SquadColors.danger, fontSize: 13),
                  ),
                ),
              ),
            if (app.recapPlans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                  child: _RecapsEmptyState(
                    onFindPlans: () => app.openShellTab(0),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final plan = app.recapPlans[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == app.recapPlans.length - 1 ? 0 : 16,
                        ),
                        child: _RecapCard(
                          plan: plan,
                          app: app,
                          formatTime: _formatPlanTime,
                        ),
                      );
                    },
                    childCount: app.recapPlans.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecapsEmptyState extends StatelessWidget {
  const _RecapsEmptyState({required this.onFindPlans});

  final VoidCallback onFindPlans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SquadColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SquadColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: SquadColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No recaps yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            "Once a plan you joined wraps, it'll show up here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: SquadColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onFindPlans,
            style: FilledButton.styleFrom(
              backgroundColor: SquadColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Find plans',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapCard extends StatefulWidget {
  const _RecapCard({
    required this.plan,
    required this.app,
    required this.formatTime,
  });

  final SquadPlan plan;
  final AppState app;
  final String Function(DateTime) formatTime;

  @override
  State<_RecapCard> createState() => _RecapCardState();
}

class _RecapCardState extends State<_RecapCard> {
  var _toggling = false;

  Future<void> _onShareChanged(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      await widget.app.toggleProfileShare(widget.plan, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Shared to your profile' : 'Removed from your profile',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update share: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final app = widget.app;
    final vibe = squadVibeForPlan(plan);
    final style = vibe != null ? kVibeMeta[vibe]! : kVibeMeta[SquadVibe.all]!;
    final attendeeIds = {
      plan.creatorId,
      ...plan.tapInUserIds,
    }.toList();
    final shared = plan.sharedToProfile;

    return Container(
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
              _VibeChip(style: style),
              _RoleBadge(isHost: plan.isHostedRecap),
              _VisibilityBadge(isPrivate: plan.isPrivate),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.formatTime(plan.startAt),
                  style: TextStyle(fontSize: 12, color: SquadColors.muted),
                ),
                if (plan.location case final loc?) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: SquadColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          loc,
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
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 32,
                width: attendeeIds.length > 4 ? 120 : 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < attendeeIds.length.clamp(0, 4); i++)
                      Positioned(
                        left: i * 22.0,
                        child: SquadInitialsAvatar(
                          initials: displayInitials(
                            app.displayNameFor(attendeeIds[i]),
                          ),
                          background: avatarColorForKey(attendeeIds[i]),
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.people_outline, size: 16, color: SquadColors.muted),
              const SizedBox(width: 4),
              Text(
                '${attendeeIds.length} went',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SquadColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: SquadColors.border, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                shared ? Icons.check_rounded : Icons.share_outlined,
                size: 18,
                color: shared ? SquadColors.primary : SquadColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shared
                          ? 'Showing on your profile'
                          : 'Share to your profile',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.isPrivate
                          ? 'Only your friends will see it'
                          : 'Anyone visiting your profile will see it',
                      style: TextStyle(
                        fontSize: 11,
                        color: SquadColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: shared,
                onChanged: _toggling ? null : _onShareChanged,
                activeTrackColor: SquadColors.primary.withValues(alpha: 0.5),
                activeThumbColor: SquadColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({required this.style});

  final VibeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.softBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${style.emoji} ${style.label}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style.softFg,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final bg = isHost
        ? SquadColors.primary.withValues(alpha: 0.15)
        : SquadColors.secondary.withValues(alpha: 0.15);
    final fg = isHost ? SquadColors.primary : SquadColors.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isHost ? 'HOSTED' : 'ATTENDED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isPrivate});

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
            isPrivate ? Icons.lock_outline : Icons.public,
            size: 12,
            color: SquadColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            isPrivate ? 'Friends' : 'Public',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SquadColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
