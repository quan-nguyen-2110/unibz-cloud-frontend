// Migrated from squadUp-layout/src/routes/create.tsx (ec99d70)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  bool _whenNow = true;
  DateTime? _whenDate;
  TimeOfDay _whenTime = const TimeOfDay(hour: 19, minute: 0);
  int _maxPeople = 2;
  PlanVisibility _visibility = PlanVisibility.public;

  static const _counts = [2, 4, 6, 8, 10];

  bool get _whenValid => _whenNow || _whenDate != null;

  String get _whenLabel {
    if (_whenNow) return 'Now';
    if (_whenDate == null) return 'Pick date & time';
    final d = DateTime(
      _whenDate!.year,
      _whenDate!.month,
      _whenDate!.day,
      _whenTime.hour,
      _whenTime.minute,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(d.year, d.month, d.day);
    final dayPart = planDay == today
        ? 'Today'
        : planDay == today.add(const Duration(days: 1))
            ? 'Tomorrow'
            : DateFormat('EEE, MMM d').format(d);
    return '$dayPart · ${DateFormat('h:mm a').format(d)}';
  }

  Future<void> _openVoice(BuildContext context) async {
    final sample = await showVoiceDictateDialog(context);
    if (sample == null || !mounted) return;
    _applyVoice(sample);
  }

  void _applyVoice(VoiceDictateSample s) {
    setState(() {
      _desc.text = s.text.length > 200 ? s.text.substring(0, 200) : s.text;
      _vibe = s.vibe;
      if (s.when == 'Now' || s.when == 'In 1 hour') {
        _whenNow = true;
      } else {
        final d = DateTime.now();
        _whenDate = s.when == 'Tomorrow'
            ? d.add(const Duration(days: 1))
            : DateTime(d.year, d.month, d.day);
        _whenNow = false;
        _whenTime = s.when == 'Today, 2:00 PM'
            ? const TimeOfDay(hour: 14, minute: 0)
            : const TimeOfDay(hour: 19, minute: 0);
      }
      _location.text = s.location;
      _maxPeople = _nearestCount(s.people);
    });
    final meta = kVibeMeta[s.vibe]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Got it! · ${meta.label} · ${s.when} · @ ${s.location}',
        ),
      ),
    );
  }

  int _nearestCount(int people) {
    var best = _counts.first;
    for (final c in _counts) {
      if ((c - people).abs() < (best - people).abs()) best = c;
    }
    return best;
  }

  @override
  void dispose() {
    _desc.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime _resolveWhen() {
    if (_whenNow) return DateTime.now();
    final d = _whenDate ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, _whenTime.hour, _whenTime.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _whenDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _whenDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _whenTime,
    );
    if (picked != null && mounted) {
      setState(() => _whenTime = picked);
    }
  }

  Future<void> _post(BuildContext context) async {
    if (!_whenValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time for your plan.')),
      );
      return;
    }

    final desc = _desc.text.trim();
    final loc = _location.text.trim();
    final meta = kVibeMeta[_vibe]!;
    final title =
        desc.isNotEmpty ? desc : '${meta.label} hangout';

    final draft = PlanDraft(
      vibeEmoji: meta.emoji,
      title: title,
      startAt: _resolveWhen(),
      description: desc.isNotEmpty ? desc : title,
      activities: [
        PlanActivity(
          emoji: meta.emoji,
          title: title,
          location: loc.isNotEmpty ? loc : 'TBD',
        ),
      ],
      location: loc.isNotEmpty ? loc : 'TBD',
      threshold: _maxPeople,
      visibility: _visibility,
    );
    await context.read<AppState>().addPlanFromDraft(draft, PlanSource.manual);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final privacyText = _visibility == PlanVisibility.private
        ? 'Only your friends will see it.'
        : 'Your squad will see it now.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Plan posted! $privacyText · ${meta.emoji} ${meta.label} · $_whenLabel',
        ),
      ),
    );
    _desc.clear();
    _location.clear();
    setState(() {
      _whenNow = true;
      _whenDate = null;
    });
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TextField(
                          controller: _desc,
                          maxLines: 4,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText:
                                'Describe the vibe… or tap the mic to speak it',
                            counterText: '',
                            contentPadding: EdgeInsets.fromLTRB(12, 12, 48, 12),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: SquadColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 2,
                            shadowColor:
                                SquadColors.primary.withValues(alpha: 0.1),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openVoice(context),
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.mic_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _WhenModeChip(
                            label: 'Now',
                            icon: Icons.bolt_rounded,
                            selected: _whenNow,
                            onTap: () => setState(() => _whenNow = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WhenModeChip(
                            label: 'Schedule',
                            icon: Icons.calendar_today_rounded,
                            selected: !_whenNow,
                            onTap: () => setState(() {
                              _whenNow = false;
                              _whenDate ??= DateTime.now();
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (!_whenNow) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ScheduleField(
                              icon: Icons.calendar_today_rounded,
                              label: _whenDate == null
                                  ? 'Pick date'
                                  : _formatDateLabel(_whenDate!),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScheduleField(
                              icon: Icons.schedule_rounded,
                              label: _whenTime.format(context),
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      _whenNow
                          ? 'Plan starts right now.'
                          : 'Starts $_whenLabel.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SquadColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Privacy',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _WhenModeChip(
                            label: 'Public',
                            icon: Icons.public_rounded,
                            selected: _visibility == PlanVisibility.public,
                            onTap: () => setState(
                              () => _visibility = PlanVisibility.public,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WhenModeChip(
                            label: 'Friends only',
                            icon: Icons.lock_rounded,
                            selected: _visibility == PlanVisibility.private,
                            onTap: () => setState(
                              () => _visibility = PlanVisibility.private,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _visibility == PlanVisibility.public
                          ? 'Anyone on SquadUp can see and join this plan.'
                          : 'Only your friends can see this plan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SquadColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
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

  String _formatDateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(d.year, d.month, d.day);
    if (planDay == today) return 'Today';
    if (planDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(d);
  }
}

class _WhenModeChip extends StatelessWidget {
  const _WhenModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SquadColors.secondary : SquadColors.inputFill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : SquadColors.text,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : SquadColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.inputFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SquadColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
