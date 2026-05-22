import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';
import '../widgets/voice_dictate_dialog.dart';

class CreateTabScreen extends StatefulWidget {
  const CreateTabScreen({super.key});

  @override
  State<CreateTabScreen> createState() => _CreateTabScreenState();
}

class _CreateTabScreenState extends State<CreateTabScreen> {
  SquadVibe _vibe = SquadVibe.gaming;
  final _desc = TextEditingController();
  final _location = TextEditingController();
  String _when = 'Now';
  int _maxPeople = 2;

  static const _whens = [
    'Now',
    'In 1 hour',
    'Today, 2:00 PM',
    'Tonight',
    'Tomorrow',
  ];
  static const _counts = [2, 4, 6, 8, 10];

  int _nearestCount(int people) {
    var best = _counts.first;
    for (final c in _counts) {
      if ((c - people).abs() < (best - people).abs()) best = c;
    }
    return best;
  }

  Future<void> _openVoice(BuildContext context) async {
    final result = await showVoiceDictateDialog(context);
    if (result == null || !mounted) return;
    setState(() {
      _desc.text = result.text.length > 200
          ? result.text.substring(0, 200)
          : result.text;
      _vibe = result.vibe;
      _when = result.when;
      _location.text = result.location;
      _maxPeople = _nearestCount(result.people);
    });
    if (!context.mounted) return;
    final meta = kVibeMeta[result.vibe]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Got it! ${meta.label} · ${result.when} · @ ${result.location}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime _resolveWhen() {
    final now = DateTime.now();
    switch (_when) {
      case 'Now':
        return now;
      case 'In 1 hour':
        return now.add(const Duration(hours: 1));
      case 'Today, 2:00 PM':
        return DateTime(now.year, now.month, now.day, 14, 0);
      case 'Tonight':
        return DateTime(now.year, now.month, now.day, 20, 0);
      case 'Tomorrow':
        final t = now.add(const Duration(days: 1));
        return DateTime(t.year, t.month, t.day, 18, 0);
      default:
        return now;
    }
  }

  Future<void> _post(BuildContext context) async {
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the plan')),
      );
      return;
    }
    final loc = _location.text.trim();
    if (loc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a location')),
      );
      return;
    }

    final meta = kVibeMeta[_vibe]!;
    final title = desc.length > 42 ? '${desc.substring(0, 42)}…' : desc;
    final draft = PlanDraft(
      vibeEmoji: meta.emoji,
      title: title,
      startAt: _resolveWhen(),
      description: desc,
      activities: [
        PlanActivity(
          emoji: meta.emoji,
          title: title,
          location: loc,
        ),
      ],
      location: loc,
      threshold: _maxPeople,
    );
    await context.read<AppState>().addPlanFromDraft(draft, PlanSource.manual);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Posted · ${meta.emoji} ${meta.label} · $_when'),
      ),
    );
    _desc.clear();
    _location.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vibes = [
      SquadVibe.hoops,
      SquadVibe.swim,
      SquadVibe.cafe,
      SquadVibe.study,
      SquadVibe.gaming,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        ScreenHeader(
          title: 'Create Plan',
          subtitle: 'Make it happen',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleToolButton(
                icon: Icons.edit_rounded,
                filled: true,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              _CircleToolButton(
                icon: Icons.mic_rounded,
                filled: false,
                onPressed: () => _openVoice(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Pick a vibe',
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.15,
                  children: [
                    for (final v in vibes)
                      _VibePickTile(
                        meta: kVibeMeta[v]!,
                        selected: _vibe == v,
                        onTap: () => setState(() => _vibe = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: "What's the plan?",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _desc,
                      maxLines: 4,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Describe the vibe…',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_desc.text.length}/200',
                        style: TextStyle(
                          fontSize: 12,
                          color: SquadColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Location',
                child: TextField(
                  controller: _location,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.place_rounded,
                      color: SquadColors.primary,
                    ),
                    hintText: "Where's it happening?",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'When',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final w in _whens) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(w),
                            selected: _when == w,
                            onSelected: (_) => setState(() => _when = w),
                            selectedColor: SquadColors.secondary,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color:
                                  _when == w ? Colors.white : SquadColors.text,
                            ),
                            backgroundColor: SquadColors.inputFill,
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Max people',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _counts)
                      ChoiceChip(
                        avatar: Icon(
                          Icons.people_rounded,
                          size: 18,
                          color: _maxPeople == c
                              ? Colors.white
                              : SquadColors.muted,
                        ),
                        label: Text('$c'),
                        selected: _maxPeople == c,
                        onSelected: (_) => setState(() => _maxPeople = c),
                        selectedColor: SquadColors.hoops,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _maxPeople == c
                              ? Colors.white
                              : SquadColors.muted,
                        ),
                        backgroundColor: SquadColors.inputFill,
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: SquadColors.ctaGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: SquadColors.primaryGlowShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _post(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Post Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
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
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  const _CircleToolButton({
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? SquadColors.primary : SquadColors.inputFill,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: filled ? Colors.white : SquadColors.muted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VibePickTile extends StatelessWidget {
  const _VibePickTile({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final VibeStyle meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: meta.softBg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? SquadColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  '${meta.emoji} ${meta.label}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: meta.softFg,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: SquadColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
