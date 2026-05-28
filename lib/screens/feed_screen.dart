// Feed home — `squadUp-layout` `index.tsx` (3d2435e).

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
import 'notifications_screen.dart';
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
  String? _filterEmoji;
  late final ScrollController _scrollController;
  static const _loadMoreThreshold = 280.0;
  bool _loadMoreQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.refreshSquadFromApi();
      app.refreshNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadMoreQueued) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent - position.pixels > _loadMoreThreshold) {
      return;
    }

    final app = context.read<AppState>();
    if (app.feedLoading || app.feedLoadingMore || !app.feedHasMore) return;

    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadMoreQueued = false;
      if (!mounted) return;
      await context.read<AppState>().loadMoreFeed();
    });
  }

  Widget _feedPlaceholder(
    BuildContext context, {
    required Widget child,
  }) {
    final minHeight = MediaQuery.sizeOf(context).height * 0.42;
    return SliverToBoxAdapter(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(child: child),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await context.read<AppState>().refreshSquadFromApi();
  }

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
        final feedPlans = mergeFeedPlansForFilter(
          recent: app.feedRecentPlans(),
          squad: app.feedSquadPlans(),
        );
        final vibeEmojis = vibeEmojisFromPlans(feedPlans);
        if (_filterEmoji != null && !vibeEmojis.contains(_filterEmoji)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _filterEmoji = null);
          });
        }
        final recentItems = app
            .feedRecentPlans()
            .where((p) => planMatchesVibeEmojiFilter(p, _filterEmoji))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final squadItems = app
            .feedSquadPlans()
            .where((p) => planMatchesVibeEmojiFilter(p, _filterEmoji))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final going = _goingCount(app);
        final incomingCount = app.incomingRequestIds.length;
        final unreadNotifs = app.unreadNotificationCount;
        final feedSubtitle = going == 0
            ? 'See what friends are up to — tap I\'m down to join.'
            : "You're in on $going plan${going == 1 ? '' : 's'}";

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: SquadColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Anyone down?',
                titleHighlight: 'down?',
                subtitle: feedSubtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SquadHeaderIconButton(
                      icon: Icons.notifications_outlined,
                      badgeCount: unreadNotifs,
                      semanticLabel: 'Notifications',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    SquadHeaderIconButton(
                      icon: Icons.people_outline_rounded,
                      badgeCount: incomingCount,
                      semanticLabel: 'Friends',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FriendsScreen(),
                          ),
                        );
                      },
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
                              'API ${AppConfig.apiBaseUrl}',
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
                selectedEmoji: _filterEmoji,
                emojis: vibeEmojis,
                labelFor: app.vibeLabelForEmoji,
                onSelect: (emoji) => setState(() => _filterEmoji = emoji),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (app.feedLoading &&
                recentItems.isEmpty &&
                squadItems.isEmpty)
              _feedPlaceholder(
                context,
                child: const CircularProgressIndicator(
                  color: SquadColors.primary,
                ),
              )
            else if (recentItems.isEmpty && squadItems.isEmpty)
              _feedPlaceholder(
                context,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _filterEmoji == null
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
              if (app.feedLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 120),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: SquadColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
          ),
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

