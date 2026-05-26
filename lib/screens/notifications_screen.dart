// Migrated from squadUp-layout/src/routes/notifications.tsx (f50f3a7).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';
import 'friends_screen.dart';
import 'plan_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Timer? _markReadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshNotifications();
    });
    _markReadTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      context.read<AppState>().markAllNotificationsRead();
    });
  }

  @override
  void dispose() {
    _markReadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final items = app.notifications;
        final subtitle = items.isEmpty
            ? 'All caught up'
            : '${items.length} update${items.length == 1 ? '' : 's'}';

        return DecoratedBox(
          decoration:
              const BoxDecoration(gradient: SquadColors.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: 'Notifications',
                    subtitle: subtitle,
                    trailing: SquadHeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: _EmptyNotificationsCard(),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _NotificationTile(
                                  notification: items[i],
                                  onTap: () => _open(context, app, items[i]),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _ClearAllButton(
                                onPressed: () => app.clearAllNotifications(),
                              ),
                            ],
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

  Future<void> _open(
    BuildContext context,
    AppState app,
    SquadNotification n,
  ) async {
    if (!n.read) {
      await app.markNotificationRead(n.id);
    }
    if (!context.mounted) return;

    if (n.planId != null && n.planId!.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PlanDetailScreen(planId: n.planId!),
        ),
      );
      return;
    }
    if (n.isFriendRequest) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
      );
    }
  }
}

class _EmptyNotificationsCard extends StatelessWidget {
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
            child: const Icon(
              Icons.notifications_outlined,
              size: 28,
              color: SquadColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: squadDisplay(context, 18),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll ping you here when a host updates a plan or someone wants to squad up.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: SquadColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.mutedBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: SquadColors.text),
              const SizedBox(width: 6),
              Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final SquadNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final icon = _iconFor(n);
    final tint = _tintFor(n);

    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(16),
      shadowColor: SquadColors.primary.withValues(alpha: 0.12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: SquadColors.cardShadow,
            border: n.read
                ? null
                : Border.all(color: SquadColors.primary.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: tint.foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!n.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SquadColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: SquadColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _TimeAgo(createdAt: n.createdAt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tint {
  const _Tint({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_Tint _tintFor(SquadNotification n) {
  if (n.isPlanCancelled) {
    return _Tint(
      background: SquadColors.danger.withValues(alpha: 0.15),
      foreground: SquadColors.danger,
    );
  }
  if (n.isFriendRequest) {
    return _Tint(
      background: SquadColors.secondary.withValues(alpha: 0.2),
      foreground: SquadColors.secondary,
    );
  }
  return _Tint(
    background: SquadColors.primary.withValues(alpha: 0.15),
    foreground: SquadColors.primary,
  );
}

IconData _iconFor(SquadNotification n) {
  if (n.isPlanCancelled) return Icons.event_busy_rounded;
  if (n.isPlanReminder) return Icons.schedule_rounded;
  if (n.isFriendRequest) return Icons.person_add_alt_1_rounded;
  if (n.isNewAttendee || n.isAttendeeLeft) return Icons.groups_rounded;
  return Icons.notifications_outlined;
}

class _TimeAgo extends StatefulWidget {
  const _TimeAgo({required this.createdAt});

  final DateTime createdAt;

  @override
  State<_TimeAgo> createState() => _TimeAgoState();
}

class _TimeAgoState extends State<_TimeAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatTimeAgo(widget.createdAt),
      style: TextStyle(
        fontSize: 11,
        color: SquadColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

String _formatTimeAgo(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  final m = diff.inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  if (m < 60 * 24) return '${m ~/ 60}h ago';
  return '${m ~/ 60 ~/ 24}d ago';
}
