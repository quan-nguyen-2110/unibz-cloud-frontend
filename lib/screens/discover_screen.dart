import 'package:flutter/material.dart';

import '../data/layout_reference_mock.dart';
import '../data/vibe_catalog.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  SquadVibe _filter = SquadVibe.all;

  @override
  Widget build(BuildContext context) {
    final visible = kDiscoverPlaces
        .where((p) => _filter == SquadVibe.all || p.vibe == _filter)
        .toList();
    final grouped = <SquadVibe, List<DiscoverPlace>>{};
    for (final p in visible) {
      grouped.putIfAbsent(p.vibe, () => []).add(p);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

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
          child: VibeChipRow(
            selected: _filter,
            onSelect: (v) => setState(() => _filter = v),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (keys.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No spots for this filter.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, sectionIndex) {
                  final vibe = keys[sectionIndex];
                  final items = grouped[vibe]!;
                  final meta = kVibeMeta[vibe]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: meta.softBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${meta.emoji} ${meta.label}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: meta.softFg,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${items.length} nearby',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: SquadColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: items.length,
                          itemBuilder: (ctx, i) =>
                              _PlaceTile(place: items[i], meta: meta),
                        ),
                      ],
                    ),
                  );
                },
                childCount: keys.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.meta});

  final DiscoverPlace place;
  final VibeStyle meta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: SquadColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: meta.softBg,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SquadColors.card.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Text(meta.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (place.open)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SquadColors.successSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Open',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: SquadColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: SquadColors.hoops),
                      const SizedBox(width: 4),
                      Text(
                        '${place.rating}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ' (${place.reviews})',
                        style: TextStyle(
                          fontSize: 12,
                          color: SquadColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: SquadColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SquadColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        place.distance,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: SquadColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
