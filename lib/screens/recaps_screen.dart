import 'package:flutter/material.dart';

import '../data/layout_reference_mock.dart';
import '../data/vibe_catalog.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';

class RecapsScreen extends StatelessWidget {
  const RecapsScreen({super.key});

  static LinearGradient _gradientFor(SquadVibe v) {
    switch (v) {
      case SquadVibe.hoops:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8A04A), Color(0xFFFF7B54)],
        );
      case SquadVibe.swim:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4DA3D8), Color(0xFF5BC0EB)],
        );
      case SquadVibe.cafe:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B4BD8), Color(0xFF9B6BEC)],
        );
      case SquadVibe.study:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A9B73), Color(0xFF34C759)],
        );
      case SquadVibe.gaming:
        return SquadColors.ctaGradient;
      case SquadVibe.all:
        return SquadColors.ctaGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(
            title: 'Recaps',
            subtitle: 'Relive the moments',
            trailing: Material(
              color: SquadColors.primary,
              shape: const CircleBorder(),
              elevation: 0,
              shadowColor: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add recap — coming soon')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final r = kRecapItems[i];
                final v = kVibeMeta[r.vibe]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _RecapCard(
                    item: r,
                    vibeLabel: v.label,
                    vibeEmoji: v.emoji,
                    gradient: _gradientFor(r.vibe),
                  ),
                );
              },
              childCount: kRecapItems.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({
    required this.item,
    required this.vibeLabel,
    required this.vibeEmoji,
    required this.gradient,
  });

  final RecapItem item;
  final String vibeLabel;
  final String vibeEmoji;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: gradient,
        boxShadow: SquadColors.primaryGlowShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: 60,
            child: IgnorePointer(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(vibeEmoji, style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$vibeLabel session'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.22)),
                const SizedBox(height: 12),
                _Line(icon: Icons.place_outlined, text: item.location),
                const SizedBox(height: 8),
                _Line(icon: Icons.calendar_today_rounded, text: item.date),
                const SizedBox(height: 8),
                _Line(icon: Icons.people_outline_rounded, text: item.people.join(', ')),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HIGHLIGHT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.highlight,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.98),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: item.shared
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white,
                      foregroundColor:
                          item.shared ? Colors.white : SquadColors.text,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.shared) ...[
                          const Icon(Icons.check_circle_outline_rounded, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.shared ? 'Shared to Story' : 'Share to Story',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
