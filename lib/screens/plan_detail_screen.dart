/// Plan detail + profile stacks live in this library to avoid import cycles
/// (`plan.$planId` ⇄ `profile.$userId` from `squadUp-layout`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../services/profile_user_resolver.dart' show mergeProfileWithCurrentUser, profileLocationLine, resolveProfileUser;
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/cancel_plan_confirm_dialog.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/leave_plan_confirm_dialog.dart';
import '../widgets/squad_layout_widgets.dart';

/// Plan detail — migrated from `squadUp-layout` `plan.$planId.tsx`.
class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

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

  void _confirmLeave(BuildContext context, AppState app, SquadPlan plan) {
    showLeavePlanConfirmDialog(
      context: context,
      planTitle: plan.title,
      onConfirmLeave: () async => app.tapOut(plan.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final plan = app.tryPlanById(planId);
        if (plan == null) {
          return DecoratedBox(
            decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Plan not found', style: squadDisplay(context, 22)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final vibe = squadVibeForPlan(plan);
        final vibeMeta = vibe != null ? kVibeMeta[vibe]! : null;
        final uid = app.currentUser?.id;
        final cancelled = app.isPlanCancelled(plan.id);
        final userIsHost = app.isHost(plan);
        final locked = plan.status == PlanStatus.locked;
        final joined = uid != null && plan.userHasTappedIn(uid);
        final canJoin = !cancelled &&
            plan.status == PlanStatus.active &&
            uid != null &&
            !joined &&
            !userIsHost;
        final spotsOpen = locked
            ? 0
            : (plan.threshold - plan.tapInCount).clamp(0, plan.threshold);

        final creatorName = app.displayNameFor(plan.creatorId);
        final hostLabel = plan.creatorId == uid ? 'You' : creatorName;

        final hostInitials = plan.creatorId == uid
            ? displayInitials(creatorName == 'User' ? 'You' : creatorName)
            : displayInitials(creatorName);
        final hostColor = avatarColorForKey(plan.creatorId);

        final heroBg = vibeMeta?.softBg ?? SquadColors.mutedBg;

        return DecoratedBox(
          decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: heroBg,
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _RoundIconButton(
                                      icon: Icons.arrow_back_rounded,
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    _RoundIconButton(
                                      icon: Icons.share_rounded,
                                      onTap: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Share link (prototype)',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (vibeMeta != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SquadColors.card,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${vibeMeta.emoji} ${vibeMeta.label}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  plan.title,
                                  style: squadDisplay(context, 28),
                                ),
                                if (userIsHost && !cancelled) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SquadColors.card,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "YOU'RE THE HOST",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -64),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  if (cancelled)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: SquadColors.danger
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: SquadColors.danger
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.block,
                                              color: SquadColors.danger),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Plan cancelled',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: SquadColors.danger,
                                                  ),
                                                ),
                                                Text(
                                                  'The host called this one off. Attendees have been notified.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: SquadColors.danger
                                                        .withValues(alpha: 0.85),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _DetailCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SquadInitialsAvatar(
                                              initials: hostInitials,
                                              background: hostColor,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Hosted by',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: SquadColors.muted,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    hostLabel,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _DetailRow(
                                          icon: Icons.schedule_rounded,
                                          label: 'When',
                                          value: _formatPlanTime(plan.startAt),
                                        ),
                                        const SizedBox(height: 12),
                                        _DetailRow(
                                          icon: Icons.place_rounded,
                                          label: 'Where',
                                          value: plan.location?.trim().isNotEmpty ==
                                                  true
                                              ? plan.location!.trim()
                                              : plan.resolvedActivities.first
                                                      .location ??
                                                  'TBD',
                                        ),
                                        const SizedBox(height: 12),
                                        _DetailRow(
                                          icon: Icons.people_rounded,
                                          label: 'Spots',
                                          value: locked
                                              ? 'Locked'
                                              : '$spotsOpen left',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _DetailCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'WHO\'S IN',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: SquadColors.muted,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...plan.tapInUserIds.map((id) {
                                          final u = app.users.cached(id);
                                          if (u == null) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 8),
                                            child: Material(
                                              color: SquadColors.inputFill,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ProfileScreen(
                                                        userId: id,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      SquadInitialsAvatar(
                                                        initials:
                                                            displayInitials(
                                                          u.displayName,
                                                        ),
                                                        background:
                                                            avatarColorForKey(
                                                          id,
                                                        ),
                                                        size: 44,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    u.displayName,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      fontSize:
                                                                          15,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (u.age !=
                                                                        null &&
                                                                    u.genderLabel !=
                                                                        null)
                                                                  Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            8),
                                                                    child: Text(
                                                                      '${u.age} · ${u.genderLabel}',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: SquadColors
                                                                            .muted,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            if (u.bio != null &&
                                                                u.bio!.trim()
                                                                    .isNotEmpty)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top: 4),
                                                                child: Text(
                                                                  u.bio!.trim(),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: SquadColors
                                                                        .muted,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                  if (!cancelled) ...[
                                    const SizedBox(height: 16),
                                    _JoinBar(
                                      locked: locked,
                                      joined: joined,
                                      isHost: userIsHost,
                                      canJoin: canJoin,
                                      onJoin: () async {
                                        HapticFeedback.lightImpact();
                                        final o = await app.tapIn(plan.id);
                                        if (o?.squadLocked == true) {
                                          HapticFeedback.mediumImpact();
                                        }
                                      },
                                      onLeave: () =>
                                          _confirmLeave(context, app, plan),
                                    ),
                                    if (userIsHost) ...[
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () {
                                          showCancelPlanConfirmDialog(
                                            context: context,
                                            planTitle: plan.title,
                                            onConfirmCancel: () async {
                                              await app.cancelPlan(plan.id);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Plan cancelled. "${plan.title}" was called off.',
                                                  ),
                                                ),
                                              );
                                              Navigator.pop(context);
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: SquadColors.danger
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: SquadColors.danger
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.block,
                                                  color: SquadColors.danger,
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Cancel plan',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color: SquadColors.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: SquadColors.text),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SquadColors.cardShadow,
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SquadColors.mutedBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: SquadColors.text),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: SquadColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JoinBar extends StatelessWidget {
  const _JoinBar({
    required this.locked,
    required this.joined,
    required this.isHost,
    required this.canJoin,
    required this.onJoin,
    required this.onLeave,
  });

  final bool locked;
  final bool joined;
  final bool isHost;
  final bool canJoin;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    if (isHost) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: SquadColors.mutedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SquadColors.border),
        ),
        alignment: Alignment.center,
        child: const Text(
          "You're hosting",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: SquadColors.muted,
          ),
        ),
      );
    }
    if (locked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: SquadColors.mutedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SquadColors.border),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Locked',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      );
    }
    if (joined) {
      return GestureDetector(
        onTap: onLeave,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: SquadColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: SquadColors.primaryGlowShadow,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "You're going",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: canJoin ? onJoin : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: SquadColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SquadColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          'Join',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: canJoin ? SquadColors.text : SquadColors.muted,
          ),
        ),
      ),
    );
  }
}

/// User profile — migrated from `squadUp-layout` `profile.$userId.tsx`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  SquadUser? _user;
  bool _loading = true;
  String? _loadError;

  static String _planSubtitle(SquadPlan p) {
    final clock = DateFormat('h:mm a');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(p.startAt.year, p.startAt.month, p.startAt.day);
    final timeStr = planDay == today
        ? 'Today, ${clock.format(p.startAt)}'
        : '${DateFormat.MMMd().format(p.startAt)}, ${clock.format(p.startAt)}';
    final loc = p.location?.trim();
    final place = (loc != null && loc.isNotEmpty) ? loc : 'TBD';
    return '$timeStr · $place';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUser());
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final app = context.read<AppState>();
    try {
      final resolved = await resolveProfileUser(
        widget.userId,
        currentUser: app.currentUser,
        lookup: app.users,
      );
      if (!mounted) return;
      final user = resolved == null
          ? null
          : mergeProfileWithCurrentUser(resolved, app.currentUser);
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Widget _profileShell({required Widget child}) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _profileShell(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return _profileShell(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Could not load profile',
                style: squadDisplay(context, 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: TextStyle(fontSize: 13, color: SquadColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadUser,
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user;
    if (user == null) {
      return _profileShell(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Profile not found', style: squadDisplay(context, 22)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back home'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AppState>(
      builder: (context, app, _) {
        final isMe = app.currentUser?.id == widget.userId;
        final displayUser =
            mergeProfileWithCurrentUser(user, app.currentUser);
        final locationLine = profileLocationLine(displayUser);
        final userPlans = app.plansInvolvingUser(widget.userId);
        final interests = displayUser.interests ?? const <String>[];
        final bioText = displayUser.bio?.trim() ?? '';

        return DecoratedBox(
          decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: SquadColors.mutedBg,
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _RoundBackButton(
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    if (isMe)
                                      _ProfileEditButton(
                                        onTap: () async {
                                          final updated =
                                              await showEditProfileDialog(
                                            context,
                                            user: displayUser,
                                          );
                                          if (!context.mounted) return;
                                          if (updated != null) {
                                            setState(() => _user = updated);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Profile saved'),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: Column(
                                    children: [
                                      SquadInitialsAvatar(
                                        initials: displayInitials(
                                          displayUser.displayName,
                                        ),
                                        background: avatarColorForKey(widget.userId),
                                        size: 80,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        displayUser.displayName,
                                        style: squadDisplay(context, 24),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      _ProfileMetaLine(
                                        user: displayUser,
                                        isMe: isMe,
                                      ),
                                      if (locationLine.isNotEmpty || isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.place_outlined,
                                                size: 14,
                                                color: SquadColors.muted,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  locationLine.isNotEmpty
                                                      ? locationLine
                                                      : 'Add location',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: SquadColors.muted,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: locationLine
                                                            .isEmpty
                                                        ? FontStyle.italic
                                                        : FontStyle.normal,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -48),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ProfileCard(
                                    title: 'ABOUT',
                                    child: Text(
                                      bioText.isNotEmpty
                                          ? bioText
                                          : (isMe
                                              ? 'No bio yet. Tap Edit to tell people about yourself.'
                                              : 'No bio yet.'),
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: bioText.isNotEmpty
                                            ? SquadColors.text
                                            : SquadColors.muted,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: bioText.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  if (interests.isNotEmpty || isMe) ...[
                                    const SizedBox(height: 16),
                                    _ProfileCard(
                                      title: 'INTERESTS',
                                      child: interests.isEmpty
                                          ? Text(
                                              'No interests yet. Tap Edit to add some.',
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.45,
                                                color: SquadColors.muted,
                                                fontWeight: FontWeight.w500,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            )
                                          : Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                for (final i in interests)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          SquadColors.mutedBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        999,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      i,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  ],
                                  if (userPlans.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _ProfileCard(
                                      title: 'IN ON',
                                      child: Column(
                                        children: [
                                          for (final p in userPlans)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Material(
                                                color: SquadColors.inputFill,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) =>
                                                            PlanDetailScreen(
                                                          planId: p.id,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                      12,
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          p.title,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          _planSubtitle(p),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: SquadColors
                                                                .muted,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  if (isMe)
                                    _ProfileLogoutButton(
                                      onPressed: () {
                                        app.logout();
                                        Navigator.of(context)
                                            .popUntil((route) => route.isFirst);
                                      },
                                    )
                                  else
                                    _ProfileFriendActions(
                                      userId: widget.userId,
                                      displayName: displayUser.displayName,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Friend / request actions at the bottom of another user's profile.
class _ProfileFriendActions extends StatelessWidget {
  const _ProfileFriendActions({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        switch (app.getFriendStatus(userId)) {
          case FriendStatus.incoming:
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: SquadColors.muted.withValues(alpha: 0.4)),
                    ),
                    onPressed: () async {
                      try {
                        await app.declineFriendRequest(userId);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not decline: $e')),
                        );
                      }
                    },
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: SquadColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        await app.acceptFriendRequest(userId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('You and $displayName are now friends!'),
                          ),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not accept: $e')),
                        );
                      }
                    },
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ],
            );
          case FriendStatus.outgoing:
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => app.cancelFriendRequest(userId),
              child: const Text(
                'Cancel request',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            );
          case FriendStatus.friend:
          case FriendStatus.none:
            return FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: SquadColors.primary,
                foregroundColor: Colors.white,
                shadowColor: SquadColors.primary.withValues(alpha: 0.35),
                elevation: 6,
              ),
              onPressed: () {
                if (app.getFriendStatus(userId) == FriendStatus.none) {
                  app.sendFriendRequest(userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request sent')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messages (prototype)')),
                );
              },
              icon: Icon(
                app.getFriendStatus(userId) == FriendStatus.none
                    ? Icons.person_add_rounded
                    : Icons.chat_bubble_outline,
              ),
              label: Text(
                app.getFriendStatus(userId) == FriendStatus.none
                    ? 'Add friend'
                    : 'Message',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            );
        }
      },
    );
  }
}

/// Age line under display name (layout: `age · gender`).
class _ProfileMetaLine extends StatelessWidget {
  const _ProfileMetaLine({required this.user, required this.isMe});

  final SquadUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final age = user.age;
    final gender = user.genderLabel?.trim();

    if (age != null) {
      final line = gender != null && gender.isNotEmpty
          ? '$age · $gender'
          : '$age';
      return Text(
        line,
        style: TextStyle(
          fontSize: 14,
          color: SquadColors.muted,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (isMe) {
      return Text(
        'Add age',
        style: TextStyle(
          fontSize: 14,
          color: SquadColors.muted,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Layout: `profile.$userId.tsx` header Edit pill when viewing own profile.
class _ProfileEditButton extends StatelessWidget {
  const _ProfileEditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      shadowColor: SquadColors.primary.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: SquadColors.text),
              const SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SquadColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layout: `profile.$userId.tsx` — muted card, destructive "Log out" CTA.
class _ProfileLogoutButton extends StatelessWidget {
  const _ProfileLogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.mutedBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 22, color: SquadColors.danger),
              const SizedBox(width: 8),
              Text(
                'Log out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SquadColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back_rounded, size: 22),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SquadColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SquadColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
