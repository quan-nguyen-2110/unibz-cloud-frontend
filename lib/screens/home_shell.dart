import 'dart:ui' show ImageFilter;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../theme/squad_theme.dart';
import 'create_tab_screen.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'recaps_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _celebrate() {
    _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: IndexedStack(
              index: _index,
              children: [
                FeedScreen(onSquadLocked: _celebrate),
                const DiscoverScreen(),
                const CreateTabScreen(),
                const RecapsScreen(),
              ],
            ),
            bottomNavigationBar: _SquadBottomNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 18,
              maxBlastForce: 25,
              minBlastForce: 8,
              gravity: 0.12,
              colors: const [
                SquadColors.primary,
                SquadColors.secondary,
                Colors.white,
                Color(0xFFFFD54F),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SquadBottomNav extends StatelessWidget {
  const _SquadBottomNav({
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SquadColors.card.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: SquadColors.border)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 10, 8, 12 + bottomInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SideNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: index == 0,
                  onTap: () => onSelect(0),
                ),
                _SideNavItem(
                  icon: Icons.map_rounded,
                  label: 'Discover',
                  selected: index == 1,
                  onTap: () => onSelect(1),
                ),
                _CenterCreateItem(
                  selected: index == 2,
                  onTap: () => onSelect(2),
                ),
                _SideNavItem(
                  icon: Icons.photo_library_outlined,
                  label: 'Recaps',
                  selected: index == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SquadColors.primary : SquadColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCreateItem extends StatelessWidget {
  const _CenterCreateItem({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? SquadColors.primary
                    : const Color(0xFFADA8BC),
                boxShadow: selected ? SquadColors.primaryGlowShadow : null,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? SquadColors.primary : SquadColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
