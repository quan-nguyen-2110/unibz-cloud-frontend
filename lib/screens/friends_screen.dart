import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';
import 'plan_detail_screen.dart';

enum _FriendsTab { friends, requests, suggested, find }

/// Friends hub — `squadUp-layout` `friends.tsx` (724828d).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  _FriendsTab _tab = _FriendsTab.friends;
  final _query = TextEditingController();
  List<SquadUser> _remoteSearchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (AppConfig.useApi) {
        app.refreshFriendsFromApi();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<SquadUser> _friends(AppState app) =>
      app.listUsersForIds(app.friendIds);

  List<SquadUser> _incoming(AppState app) =>
      app.listUsersForIds(app.incomingRequestIds);

  List<SquadUser> _outgoing(AppState app) =>
      app.listUsersForIds(app.outgoingRequestIds);

  List<SquadUser> _searchLocal(AppState app, String q) {
    final me = app.currentUser?.id;
    final lower = q.trim().toLowerCase();
    if (lower.isEmpty) return [];
    return app.visibleUsers().where((u) {
      if (u.id == me) return false;
      if (u.displayName.toLowerCase().contains(lower)) return true;
      if ((u.profileLocation ?? u.city).toLowerCase().contains(lower)) {
        return true;
      }
      return (u.interests ?? []).any((i) => i.toLowerCase().contains(lower));
    }).toList();
  }

  Future<void> _runRemoteSearch(AppState app, String q) async {
    final trimmed = q.trim();
    if (trimmed.length < 2) {
      setState(() {
        _remoteSearchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await app.searchUsersRemote(trimmed);
    if (!mounted) return;
    setState(() {
      _remoteSearchResults = results;
      _searching = false;
    });
  }

  String? _sharedInterestHint(AppState app, SquadUser u) {
    final mine = Set<String>.from(app.currentUser?.interests ?? []);
    final shared = (u.interests ?? []).where(mine.contains).toList();
    if (shared.isEmpty) return null;
    final slice = shared.take(2).join(' & ');
    return 'You both like $slice';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
        final friends = _friends(app);
        final incoming = _incoming(app);
        final suggested = app.suggestedFriends(limit: 8);
        final q = _query.text;
        final results =
            AppConfig.useApi ? _remoteSearchResults : _searchLocal(app, q);

        return DecoratedBox(
          decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        Material(
                          color: SquadColors.card,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.arrow_back_rounded, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Friends', style: squadDisplay(context, 26)),
                              Text(
                                '${friends.length} friend${friends.length == 1 ? '' : 's'}'
                                '${incoming.isNotEmpty ? ' · ${incoming.length} new request${incoming.length == 1 ? '' : 's'}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: incoming.isNotEmpty
                                      ? SquadColors.primary
                                      : SquadColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _TabChip(
                          label: 'Friends',
                          count: friends.length,
                          selected: _tab == _FriendsTab.friends,
                          onTap: () => setState(() => _tab = _FriendsTab.friends),
                        ),
                        const SizedBox(width: 8),
                        _TabChip(
                          label: 'Requests',
                          count: incoming.length,
                          selected: _tab == _FriendsTab.requests,
                          onTap: () => setState(() => _tab = _FriendsTab.requests),
                        ),
                        const SizedBox(width: 8),
                        _TabChip(
                          label: 'Suggested',
                          selected: _tab == _FriendsTab.suggested,
                          onTap: () => setState(() => _tab = _FriendsTab.suggested),
                        ),
                        const SizedBox(width: 8),
                        _TabChip(
                          label: 'Find',
                          selected: _tab == _FriendsTab.find,
                          onTap: () => setState(() => _tab = _FriendsTab.find),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: switch (_tab) {
                      _FriendsTab.friends => friends.isEmpty
                          ? const _EmptyCard(
                              icon: Icons.people_outline,
                              title: 'No friends yet',
                              hint:
                                  'Tap Suggested or Find to start growing your squad.',
                            )
                          : Column(
                              children: [
                                for (final u in friends)
                                  _PersonRow(
                                    user: u,
                                    action: _RemoveButton(
                                      onPressed: () => app.removeFriend(u.id),
                                    ),
                                    onOpenProfile: () => _openProfile(context, u.id),
                                  ),
                              ],
                            ),
                      _FriendsTab.requests => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionLabel('Incoming'),
                            if (incoming.isEmpty)
                              const _EmptyCard(
                                icon: Icons.person_add_outlined,
                                title: 'No incoming requests',
                              )
                            else
                              for (final u in incoming)
                                _PersonRow(
                                  user: u,
                                  onOpenProfile: () => _openProfile(context, u.id),
                                  action: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _SmallActionButton(
                                        label: 'Accept',
                                        icon: Icons.check_rounded,
                                        primary: true,
                                        onPressed: () {
                                          app.acceptFriendRequest(u.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'You and ${u.displayName} are now friends!',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _SmallActionButton(
                                        label: 'Decline',
                                        onPressed: () =>
                                            app.declineFriendRequest(u.id),
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 16),
                            const _SectionLabel('Sent'),
                            if (_outgoing(app).isEmpty)
                              const _EmptyCard(
                                icon: Icons.check_circle_outline,
                                title: 'No pending sent requests',
                              )
                            else
                              for (final u in _outgoing(app))
                                _PersonRow(
                                  user: u,
                                  onOpenProfile: () => _openProfile(context, u.id),
                                  action: _SmallActionButton(
                                    label: 'Cancel',
                                    icon: Icons.close_rounded,
                                    onPressed: () =>
                                        app.cancelFriendRequest(u.id),
                                  ),
                                ),
                          ],
                        ),
                      _FriendsTab.suggested => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 16, color: SquadColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'BASED ON YOUR INTERESTS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: SquadColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (suggested.isEmpty)
                              const _EmptyCard(
                                icon: Icons.auto_awesome_outlined,
                                title: 'No suggestions right now',
                                hint:
                                    'Add interests to your profile to get matches.',
                              )
                            else
                              for (final u in suggested)
                                _PersonRow(
                                  user: u,
                                  hint: _sharedInterestHint(app, u),
                                  onOpenProfile: () => _openProfile(context, u.id),
                                  action: _AddFriendButton(
                                    app: app,
                                    user: u,
                                  ),
                                ),
                          ],
                        ),
                      _FriendsTab.find => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _query,
                              onChanged: (value) {
                                setState(() {});
                                if (AppConfig.useApi) {
                                  _runRemoteSearch(app, value);
                                }
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, interest, or location',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: SquadColors.card,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (q.trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'Type a name, interest, or city to find people.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: SquadColors.muted),
                                ),
                              )
                            else if (_searching)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (results.isEmpty)
                              _EmptyCard(
                                icon: Icons.search_off_outlined,
                                title: 'No matches',
                                hint: 'Nothing for "${q.trim()}".',
                              )
                            else
                              for (final u in results)
                                _PersonRow(
                                  user: u,
                                  onOpenProfile: () => _openProfile(context, u.id),
                                  action: _AddFriendButton(app: app, user: u),
                                ),
                          ],
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openProfile(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SquadColors.primary : SquadColors.mutedBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : SquadColors.text,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : SquadColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : SquadColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: SquadColors.muted,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SquadColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SquadColors.mutedBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: SquadColors.muted),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: SquadColors.muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.user,
    required this.onOpenProfile,
    this.action,
    this.hint,
  });

  final SquadUser user;
  final VoidCallback onOpenProfile;
  final Widget? action;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final loc = user.profileLocation ?? user.city;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SquadColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: SquadColors.cardShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenProfile,
            child: SquadInitialsAvatar(
              initials: displayInitials(user.displayName),
              background: avatarColorForKey(user.id),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.age != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${user.age} · $loc',
                          style: TextStyle(
                            fontSize: 12,
                            color: SquadColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint ?? user.bio ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: SquadColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? SquadColors.primary : SquadColors.mutedBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: primary ? Colors.white : SquadColors.text,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary ? Colors.white : SquadColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SmallActionButton(
      label: 'Remove',
      icon: Icons.person_remove_outlined,
      onPressed: onPressed,
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.app, required this.user});

  final AppState app;
  final SquadUser user;

  @override
  Widget build(BuildContext context) {
    switch (app.getFriendStatus(user.id)) {
      case FriendStatus.friend:
        return _SmallActionButton(
          label: 'Friends',
          icon: Icons.check_rounded,
          onPressed: () {},
        );
      case FriendStatus.outgoing:
        return _SmallActionButton(
          label: 'Requested',
          icon: Icons.close_rounded,
          onPressed: () => app.cancelFriendRequest(user.id),
        );
      case FriendStatus.incoming:
        return _SmallActionButton(
          label: 'Accept',
          icon: Icons.check_rounded,
          primary: true,
          onPressed: () {
            app.acceptFriendRequest(user.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You and ${user.displayName} are now friends!'),
              ),
            );
          },
        );
      case FriendStatus.none:
        return _SmallActionButton(
          label: 'Add',
          icon: Icons.person_add_rounded,
          primary: true,
          onPressed: () {
            app.sendFriendRequest(user.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent to ${user.displayName}.'),
              ),
            );
          },
        );
    }
  }
}
