import 'package:flutter/material.dart';

import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';

class RecapsScreen extends StatelessWidget {
  const RecapsScreen({super.key});

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
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 48, color: SquadColors.muted),
                const SizedBox(height: 16),
                const Text(
                  'No recaps yet',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed plans will show recap cards here once the recap worker is live.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SquadColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
