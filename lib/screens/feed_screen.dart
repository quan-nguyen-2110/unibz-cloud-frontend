import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/plan_card_widget.dart';
import '../widgets/squad_layout_widgets.dart';
import 'friends_screen.dart';
import 'plan_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.onSquadLocked,
  });

  final VoidCallback onSquadLocked;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  SquadVibe _filter = SquadVibe.all;

  int _goingCount(AppState app) {
    final uid = app.currentUser?.id;
    if (uid == null) return 0;
    return app
        .friendFeed()
        .where((p) => p.userHasTappedIn(uid))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final uid = app.currentUser?.id;
        final recentItems = app
            .feedRecentPlans()
            .where((p) => planMatchesVibeFilter(p, _filter))
            .toList();
        final squadItems = app
            .feedSquadPlans()
            .where((p) => planMatchesVibeFilter(p, _filter))
            .toList();
        final going = _goingCount(app);
        final me = app.currentUser;
        final incomingCount = app.incomingRequestIds.length;
        final feedSubtitle = going == 0
            ? 'See what friends are up to — tap I\'m down to join.'
            : "You're in on $going plan${going == 1 ? '' : 's'}";

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Anyone down?',
                titleHighlight: 'down?',
                subtitle: feedSubtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FriendsHeaderButton(incomingCount: incomingCount),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (uid == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(userId: uid),
                          ),
                        );
                      },
                      child: SquadInitialsAvatar(
                        initials: displayInitials(me?.displayName ?? 'YO'),
                        background: SquadColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (kDebugMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.apiProbeMessage ??
                              'API ${AppConfig.apiBaseUrl}${AppConfig.useApi ? " (live)" : ""}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Test API (health + feed)',
                        icon: const Icon(Icons.cloud_sync_outlined),
                        onPressed: () async {
                          final msg = await app.probeBackend();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: VibeChipRow(
                selected: _filter,
                onSelect: (v) => setState(() => _filter = v),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (recentItems.isEmpty && squadItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _filter == SquadVibe.all
                            ? 'Your feed\'s quiet.'
                            : 'Nothing for this vibe yet.',
                        style: squadDisplay(context, 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Post a plan from the Create tab or widen the filter.',
                        style: TextStyle(
                          color: SquadColors.muted.withValues(alpha: 0.95),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (recentItems.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 16, color: SquadColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'RECENTLY CREATED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SquadColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${recentItems.length} new',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: SquadColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildPlanCard(
                        context,
                        app,
                        recentItems[i],
                        uid,
                      ),
                      childCount: recentItems.length,
                    ),
                  ),
                ),
                if (squadItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: SquadColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'FROM YOUR SQUAD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: SquadColors.muted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: SquadColors.border)),
                        ],
                      ),
                    ),
                  ),
              ],
              if (squadItems.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    recentItems.isEmpty ? 0 : 0,
                    24,
                    120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildPlanCard(
                        context,
                        app,
                        squadItems[i],
                        uid,
                      ),
                      childCount: squadItems.length,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    AppState app,
    SquadPlan plan,
    String? uid,
  ) {
    return PlanCardWidget(
      plan: plan,
      currentUserId: uid,
      onOpenDetail: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlanDetailScreen(planId: plan.id),
          ),
        );
      },
      nameFor: app.displayNameFor,
      onTapIn: () async {
        final o = await app.tapIn(plan.id);
        if (o != null && !o.squadLocked) {
          final messenger = ScaffoldMessenger.of(context);
          final planId = plan.id;
          messenger.clearSnackBars();
          const dismissAfter = Duration(seconds: 4);
          messenger.showSnackBar(
            SnackBar(
              content: const Text("You're in"),
              duration: dismissAfter,
              showCloseIcon: true,
              closeIconColor: Colors.white,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  unawaited(app.tapOut(planId));
                },
              ),
            ),
          );
          Future<void>.delayed(dismissAfter, () {
            if (!context.mounted) return;
            messenger.hideCurrentSnackBar();
          });
        }
        return o;
      },
      onTapOut: () async => app.tapOut(plan.id),
      onLocked: widget.onSquadLocked,
      onLongPressCreator: (cid) {
        app.blockUser(cid);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blocked (prototype — local only)'),
            duration: Duration(seconds: 4),
            showCloseIcon: true,
            closeIconColor: Colors.white,
          ),
        );
      },
    );
  }
}

class _FriendsHeaderButton extends StatelessWidget {
  const _FriendsHeaderButton({required this.incomingCount});

  final int incomingCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.people_outline_rounded, size: 22),
            ),
            if (incomingCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: SquadColors.primary,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: SquadColors.card, width: 2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$incomingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
