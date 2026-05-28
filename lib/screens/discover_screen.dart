import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String? _filterEmoji;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) {
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
        return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(
            title: 'Discover',
            subtitle: 'Places near you to hang',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: SquadColors.card,
                borderRadius: BorderRadius.circular(999),
                boxShadow: SquadColors.cardShadow,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_rounded, size: 18, color: SquadColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Nearby',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: VibeChipRow(
              selectedEmoji: _filterEmoji,
              emojis: vibeEmojis,
              onSelect: (emoji) => setState(() => _filterEmoji = emoji),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, size: 48, color: SquadColors.muted),
                const SizedBox(height: 16),
                const Text(
                  'No places yet',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Venue listings will appear here once connected to the API.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SquadColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }
}
