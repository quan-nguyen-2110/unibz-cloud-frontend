import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../models/models.dart';
import '../services/api_loading.dart';
import '../services/app_datetime.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import '../widgets/squad_layout_widgets.dart';

/// Host-only editor for plans that have not started yet.
class EditPlanScreen extends StatefulWidget {
  const EditPlanScreen({super.key, required this.plan});

  final SquadPlan plan;

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  static const _counts = [2, 4, 6, 8, 10];
  static const _unlimitedThreshold = 99;
  static const _minDuration = 5;
  static const _maxDuration = 1440;
  static const _durationPresets = <(String, int)>[
    ('30m', 30),
    ('1h', 60),
    ('1h 30m', 90),
    ('2h', 120),
    ('3h', 180),
    ('4h', 240),
  ];

  late SquadVibe _vibe;
  late final TextEditingController _desc;
  late final TextEditingController _location;
  late DateTime _whenDate;
  late TimeOfDay _whenTime;
  late bool _maxUnlimited;
  late final TextEditingController _customMax;
  int? _durationMinutes;
  late final TextEditingController _customDuration;
  late PlanVisibility _visibility;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _vibe = squadVibeForPlan(plan) ?? SquadVibe.gaming;
    final text = (plan.description?.trim().isNotEmpty == true
            ? plan.description!
            : plan.title)
        .trim();
    _desc = TextEditingController(text: text);
    final loc = plan.location?.trim();
    _location = TextEditingController(
      text: loc?.isNotEmpty == true
          ? loc!
          : (plan.resolvedActivities.isNotEmpty
              ? plan.resolvedActivities.first.location ?? ''
              : ''),
    );
    final start = AppDateTime.toLocal(plan.startAt);
    _whenDate = DateTime(start.year, start.month, start.day);
    _whenTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _maxUnlimited = plan.threshold >= _unlimitedThreshold;
    _customMax = TextEditingController(
      text: _maxUnlimited ? '2' : plan.threshold.toString(),
    );
    _durationMinutes = plan.durationMinutes;
    _customDuration = TextEditingController(
      text: _durationMinutes == null ? '' : '$_durationMinutes',
    );
    _visibility = plan.visibility;
  }

  @override
  void dispose() {
    _desc.dispose();
    _location.dispose();
    _customMax.dispose();
    _customDuration.dispose();
    super.dispose();
  }

  int get _parsedMaxPeople {
    final n = int.tryParse(_customMax.text.trim());
    if (n == null || n < 2) return 2;
    return n.clamp(2, 100);
  }

  void _setDuration(int minutes) {
    final clamped = minutes.clamp(_minDuration, _maxDuration);
    setState(() {
      _durationMinutes = clamped;
      final text = '$clamped';
      if (_customDuration.text != text) _customDuration.text = text;
    });
  }

  void _onCustomDurationChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _durationMinutes = null);
      return;
    }
    final n = int.tryParse(trimmed);
    if (n == null) return;
    setState(() => _durationMinutes = n.clamp(_minDuration, _maxDuration));
  }

  int get _saveThreshold =>
      _maxUnlimited ? _unlimitedThreshold : _parsedMaxPeople;

  DateTime get _startAt => DateTime(
        _whenDate.year,
        _whenDate.month,
        _whenDate.day,
        _whenTime.hour,
        _whenTime.minute,
      );

  String get _whenLabel => AppDateTime.formatSchedule(_startAt);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _whenDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _whenDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _whenTime,
    );
    if (picked != null && mounted) setState(() => _whenTime = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_startAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a future date and time.')),
      );
      return;
    }

    setState(() => _saving = true);
    final meta = kVibeMeta[_vibe]!;
    final desc = _desc.text.trim();
    final loc = _location.text.trim();
    final title = desc.isNotEmpty ? desc : '${meta.label} hangout';

    final draft = PlanDraft(
      vibeEmoji: meta.emoji,
      title: title,
      startAt: _startAt,
      description: desc.isNotEmpty ? desc : title,
      activities: [
        PlanActivity(
          emoji: meta.emoji,
          title: title,
          location: loc.isNotEmpty ? loc : 'TBD',
        ),
      ],
      location: loc.isNotEmpty ? loc : 'TBD',
      threshold: _saveThreshold,
      durationMinutes: _durationMinutes,
      visibility: _visibility,
    );

    try {
      final updated = await ApiLoading.runSilently(
        () => context
            .read<AppState>()
            .updatePlanFromDraft(widget.plan.id, draft),
      );
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save plan. Try again.')),
        );
        return;
      }
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibes = [
      SquadVibe.hoops,
      SquadVibe.swim,
      SquadVibe.cafe,
      SquadVibe.study,
      SquadVibe.gaming,
      SquadVibe.outdoors,
      SquadVibe.movie,
      SquadVibe.party,
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SquadColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _saving,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    ScreenHeader(
                      title: 'Edit plan',
                      subtitle: widget.plan.title,
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EditSection(
                            title: 'Vibe',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final v in vibes)
                                  Builder(
                                    builder: (context) {
                                      final meta = kVibeMeta[v] ??
                                          const VibeStyle(
                                            label: 'Vibe',
                                            emoji: '✨',
                                            softBg: SquadColors.mutedBg,
                                            softFg: SquadColors.text,
                                          );
                                      return FilterChip(
                                        label: Text(
                                          '${meta.emoji} ${meta.label}',
                                        ),
                                        selected: _vibe == v,
                                        onSelected: (_) =>
                                            setState(() => _vibe = v),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'What\'s the plan?',
                            child: TextField(
                              controller: _desc,
                              maxLength: 200,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Describe your plan…',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'Where',
                            child: TextField(
                              controller: _location,
                              decoration: const InputDecoration(
                                hintText: 'Location',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'When',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_whenLabel),
                                  trailing:
                                      const Icon(Icons.calendar_today_rounded),
                                  onTap: _pickDate,
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    DateFormat('h:mm a')
                                        .format(AppDateTime.toLocal(_startAt)),
                                  ),
                                  trailing:
                                      const Icon(Icons.schedule_rounded),
                                  onTap: _pickTime,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'Max squad size',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Unlimited'),
                                  value: _maxUnlimited,
                                  onChanged: (v) => setState(() {
                                    _maxUnlimited = v;
                                  }),
                                ),
                                if (!_maxUnlimited) ...[
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final c in _counts)
                                        ChoiceChip(
                                          label: Text('$c'),
                                          selected:
                                              _parsedMaxPeople == c &&
                                                  !_maxUnlimited,
                                          onSelected: (_) {
                                            setState(() {
                                              _customMax.text = '$c';
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _customMax,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Custom max',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'How long',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Not sure'),
                                      selected: _durationMinutes == null,
                                      onSelected: (_) => setState(() {
                                        _durationMinutes = null;
                                        _customDuration.clear();
                                      }),
                                    ),
                                    for (final preset in _durationPresets)
                                      ChoiceChip(
                                        label: Text(preset.$1),
                                        selected: _durationMinutes == preset.$2,
                                        onSelected: (_) =>
                                            _setDuration(preset.$2),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _customDuration,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Custom minutes',
                                    helperText: 'Leave empty for "Not sure"',
                                    suffixText: 'minutes',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: _onCustomDurationChanged,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _EditSection(
                            title: 'Who can see it',
                            child: SegmentedButton<PlanVisibility>(
                              segments: const [
                                ButtonSegment(
                                  value: PlanVisibility.public,
                                  label: Text('Public'),
                                ),
                                ButtonSegment(
                                  value: PlanVisibility.private,
                                  label: Text('Friends'),
                                ),
                              ],
                              selected: {_visibility},
                              onSelectionChanged: (s) =>
                                  setState(() => _visibility = s.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: SquadColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
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

class _EditSection extends StatelessWidget {
  const _EditSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SquadColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
