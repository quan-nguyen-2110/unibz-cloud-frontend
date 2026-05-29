// Migrated from squadUp-layout/src/routes/create.tsx (a1e9b94)

import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/vibe_catalog.dart';
import '../services/app_datetime.dart';
import '../models/models.dart';
import '../services/api_loading.dart';
import '../state/app_state.dart';
import '../theme/squad_theme.dart';
import 'plan_detail_screen.dart';
import '../widgets/plan_photo_upload_overlay.dart';
import '../widgets/squad_layout_widgets.dart';
import '../widgets/voice_dictate_dialog.dart';

class CreateTabScreen extends StatefulWidget {
  const CreateTabScreen({super.key});

  @override
  State<CreateTabScreen> createState() => _CreateTabScreenState();
}

class _CreateTabScreenState extends State<CreateTabScreen> {
  SquadVibe _vibe = SquadVibe.gaming;
  String? _customVibeEmoji;
  final List<String> _aiExtraVibeEmojis = [];
  final Map<String, String> _aiVibeLabels = {};
  final _desc = TextEditingController();
  final _location = TextEditingController();
  bool _whenNow = true;
  DateTime? _whenDate;
  TimeOfDay _whenTime = const TimeOfDay(hour: 19, minute: 0);
  bool _maxUnlimited = false;
  final _customMax = TextEditingController(text: '2');

  /// Estimated time the whole event takes, in minutes. Defaults to 1h.
  int _durationMinutes = 60;
  final _customDuration = TextEditingController(text: '60');
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
  PlanVisibility _visibility = PlanVisibility.public;
  final List<XFile> _photos = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _posting = false;
  bool _voicePrefilled = false;
  String? _voiceTranscript;

  static const _counts = [2, 4, 6, 8, 10];
  static const _maxPhotos = 5;
  /// Matches layout `spotsLeft: null` — app uses threshold ≥ 99 as unlimited.
  static const _unlimitedThreshold = 99;

  bool get _whenValid => _whenNow || _whenDate != null;

  String get _whenLabel {
    if (_whenNow) return 'Now';
    if (_whenDate == null) return 'Pick date & time';
    return AppDateTime.formatSchedule(DateTime(
      _whenDate!.year,
      _whenDate!.month,
      _whenDate!.day,
      _whenTime.hour,
      _whenTime.minute,
    ));
  }

  Future<void> _openVoice(BuildContext context) async {
    final sample = await showVoiceDictateDialog(context);
    if (sample == null || !mounted) return;
    _applyVoice(sample);
  }

  void _applyVoice(VoiceDictateSample s) {
    final now = DateTime.now();
    final localStart = AppDateTime.toLocal(s.startAt);
    final isNowish = localStart.isBefore(now.add(const Duration(minutes: 10)));
    final mapped = squadVibeFromEmoji(s.vibeEmoji);
    setState(() {
      final desc = s.description.trim().isNotEmpty ? s.description.trim() : s.text.trim();
      _desc.text = desc.length > 200 ? desc.substring(0, 200) : desc;
      if (mapped != null) {
        _vibe = mapped;
        _customVibeEmoji = null;
      } else {
        _customVibeEmoji = s.vibeEmoji.trim().isEmpty ? null : s.vibeEmoji.trim();
        if (_customVibeEmoji != null) {
          if (!_aiExtraVibeEmojis.contains(_customVibeEmoji)) {
            _aiExtraVibeEmojis.add(_customVibeEmoji!);
          }
          final label = _vibeLabelFromVoice(s.vibeName, _customVibeEmoji!);
          if (label != null) _aiVibeLabels[_customVibeEmoji!] = label;
        }
      }
      _voicePrefilled = true;
      _voiceTranscript = s.text;
      if (isNowish) {
        _whenNow = true;
      } else {
        _whenDate = DateTime(localStart.year, localStart.month, localStart.day);
        _whenNow = false;
        _whenTime = TimeOfDay(hour: localStart.hour, minute: localStart.minute);
      }
      _location.text = s.location;
      _maxUnlimited = s.people < 0;
      if (_maxUnlimited) {
        _customMax.text = '2';
      } else {
        _customMax.text = '${s.people.clamp(2, 100)}';
      }
      if (s.durationMinutes != null) {
        _durationMinutes =
            s.durationMinutes!.clamp(_minDuration, _maxDuration);
        _customDuration.text = '$_durationMinutes';
      }
    });
    final meta = _customVibeEmoji != null
        ? _styleForCustomEmoji(_customVibeEmoji!)
        : (kVibeMeta[_vibe] ?? _fallbackVibeStyle);
    final whenLabel = isNowish
        ? 'Now'
        : AppDateTime.formatSchedule(localStart);
    final durationLabel = ' · ${_durationLabel(_durationMinutes)}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Got it! · ${meta.label} · $whenLabel · @ ${s.location}'
          '${s.people < 0 ? ' · Unlimited' : ' · max ${s.people}'}'
          '$durationLabel',
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Sets the duration and keeps the custom-minutes field text in sync.
  void _setDuration(int minutes) {
    final clamped = minutes.clamp(_minDuration, _maxDuration);
    setState(() {
      _durationMinutes = clamped;
      final text = '$clamped';
      if (_customDuration.text != text) {
        _customDuration.text = text;
      }
    });
  }

  void _onCustomDurationChanged(String value) {
    final n = int.tryParse(value.trim());
    if (n == null) return;
    setState(() => _durationMinutes = n.clamp(_minDuration, _maxDuration));
  }

  int get _parsedMaxPeople {
    final n = int.tryParse(_customMax.text.trim());
    if (n == null || n < 2) return 2;
    return n.clamp(2, 100);
  }

  int get _postThreshold =>
      _maxUnlimited ? _unlimitedThreshold : _parsedMaxPeople;

  void _onCustomMaxChanged(String value) {
    if (_maxUnlimited) return;
    final n = int.tryParse(value);
    if (n != null && n >= 1) setState(() {});
  }

  void _clearForm(BuildContext context) {
    setState(() {
      _vibe = SquadVibe.gaming;
      _customVibeEmoji = null;
      _aiExtraVibeEmojis.clear();
      _aiVibeLabels.clear();
      _desc.clear();
      _location.clear();
      _whenNow = true;
      _whenDate = null;
      _whenTime = const TimeOfDay(hour: 19, minute: 0);
      _maxUnlimited = false;
      _customMax.text = '2';
      _durationMinutes = 60;
      _customDuration.text = '60';
      _visibility = PlanVisibility.public;
      _photos.clear();
      _voicePrefilled = false;
      _voiceTranscript = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form cleared'),
      ),
    );
  }

  @override
  void dispose() {
    _desc.dispose();
    _location.dispose();
    _customMax.dispose();
    _customDuration.dispose();
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
    if (_posting) return;
    if (!_whenValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time for your plan.')),
      );
      return;
    }

    setState(() => _posting = true);
    // Paint loading overlay before the network work starts.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final desc = _desc.text.trim();
    final loc = _location.text.trim();
    final meta = _selectedVibeStyle;
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
      threshold: _postThreshold,
      durationMinutes: _durationMinutes,
      transcript: _voicePrefilled ? _voiceTranscript : null,
      visibility: _visibility,
    );
    final source = _voicePrefilled ? PlanSource.voice : PlanSource.manual;
    SquadPlan? plan;
    try {
      plan = await ApiLoading.runSilently(
        () => context.read<AppState>().addPlanFromDraft(
          draft,
          source,
          localPhotos: List<XFile>.from(_photos),
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
    if (!mounted) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post plan. Try again.')),
      );
      return;
    }

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
      _photos.clear();
      _customVibeEmoji = null;
      _voicePrefilled = false;
      _voiceTranscript = null;
    });

    final planId = plan.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(planId: planId),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(picked.take(remaining));
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibes = [
      SquadVibe.all,
      SquadVibe.hoops,
      SquadVibe.swim,
      SquadVibe.cafe,
      SquadVibe.study,
      SquadVibe.gaming,
      SquadVibe.outdoors,
      SquadVibe.movie,
      SquadVibe.party,
    ];
    final catalogEmojis = vibes
        .map((v) => (kVibeMeta[v] ?? _fallbackVibeStyle).emoji)
        .toSet();
    final aiGridEmojis = _aiExtraVibeEmojis
        .where((e) => !catalogEmojis.contains(e))
        .toList();
    final vibeGridCount = vibes.length + aiGridEmojis.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(
          absorbing: _posting,
          child: ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        ScreenHeader(
          title: 'Create Plan',
          subtitle: 'Make it happen',
          trailing: _CircleToolButton(
            icon: Icons.mic_rounded,
            onPressed: () => _openVoice(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Pick a vibe',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxTileWidth =
                        constraints.maxWidth >= 420 ? 160.0 : 140.0;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxTileWidth,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: vibeGridCount,
                      itemBuilder: (context, i) {
                        if (i < vibes.length) {
                          final v = vibes[i];
                          return _VibePickTile(
                            meta: kVibeMeta[v] ?? _fallbackVibeStyle,
                            selected: _customVibeEmoji == null && _vibe == v,
                            onTap: () => setState(() {
                              _vibe = v;
                              _customVibeEmoji = null;
                            }),
                          );
                        }
                        final emoji = aiGridEmojis[i - vibes.length];
                        return _VibePickTile(
                          meta: _styleForCustomEmoji(emoji),
                          selected: _customVibeEmoji == emoji,
                          onTap: () => setState(() => _customVibeEmoji = emoji),
                        );
                      },
                    );
                  },
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
                                  : AppDateTime.formatDateLabel(_whenDate!),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: _maxUnlimited ? 0.5 : 1,
                            child: Material(
                              color: SquadColors.inputFill,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.people_rounded,
                                      size: 18,
                                      color: SquadColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _maxUnlimited
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              child: Text(
                                                '∞',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: SquadColors.muted,
                                                ),
                                              ),
                                            )
                                          : TextField(
                                              controller: _customMax,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                              ),
                                              onChanged: _onCustomMaxChanged,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: _maxUnlimited
                              ? SquadColors.hoops
                              : SquadColors.inputFill,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(
                              () => _maxUnlimited = !_maxUnlimited,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Text(
                                'Unlimited',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _maxUnlimited
                                      ? Colors.white
                                      : SquadColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _counts)
                          Material(
                            color: !_maxUnlimited && _parsedMaxPeople == c
                                ? SquadColors.primary.withValues(alpha: 0.15)
                                : SquadColors.mutedBg,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => setState(() {
                                _maxUnlimited = false;
                                _customMax.text = '$c';
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '$c',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: !_maxUnlimited &&
                                            _parsedMaxPeople == c
                                        ? SquadColors.primary
                                        : SquadColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'How long',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Roughly how long will this plan run?',
                      style: TextStyle(
                        fontSize: 12,
                        color: SquadColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in _durationPresets)
                          _DurationChip(
                            label: preset.$1,
                            selected: _durationMinutes == preset.$2,
                            onTap: () => _setDuration(preset.$2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _CustomDurationField(
                      controller: _customDuration,
                      onChanged: _onCustomDurationChanged,
                      onStep: (delta) =>
                          _setDuration(_durationMinutes + delta),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Photos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add up to $_maxPhotos pictures so people can feel the vibe.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SquadColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _photos.length +
                          (_photos.length < _maxPhotos ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i < _photos.length) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _CreatePhotoThumb(file: _photos[i]),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: SquadColors.card
                                      .withValues(alpha: 0.9),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => setState(
                                      () => _photos.removeAt(i),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Material(
                          color: SquadColors.inputFill,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickPhotos,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: SquadColors.muted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _photos.isEmpty ? 'Add' : 'More',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: SquadColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_photos.length}/$_maxPhotos',
                      style: TextStyle(
                        fontSize: 11,
                        color: SquadColors.muted,
                      ),
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
              Opacity(
                opacity: _posting ? 0.7 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: SquadColors.ctaGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: SquadColors.primaryGlowShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _posting ? null : () => _post(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_posting)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            else
                              const Icon(Icons.send_rounded, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              _posting ? 'Posting…' : 'Post Plan',
                              style: const TextStyle(
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
              ),
              const SizedBox(height: 10),
              Material(
                color: SquadColors.inputFill,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _posting ? null : () => _clearForm(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: SquadColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: SquadColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    ),
        ),
        if (_posting)
          Consumer<AppState>(
            builder: (context, app, _) {
              final photoProgress = app.planPhotoUploadProgress;
              if (photoProgress != null) {
                return PlanPhotoUploadScreenOverlay(
                  title: photoProgress.title,
                  progress: photoProgress,
                );
              }
              return const PlanPhotoUploadScreenOverlay(
                title: 'Posting your plan…',
                subtitle: 'Hang tight for a moment',
              );
            },
          ),
      ],
    );
  }

  static const VibeStyle _fallbackVibeStyle = VibeStyle(
    label: 'Vibe',
    emoji: '✨',
    softBg: SquadColors.mutedBg,
    softFg: SquadColors.text,
  );

  VibeStyle get _selectedVibeStyle {
    if (_customVibeEmoji != null) return _styleForCustomEmoji(_customVibeEmoji!);
    return kVibeMeta[_vibe] ?? _fallbackVibeStyle;
  }

  String? _vibeLabelFromVoice(String? vibeName, String emoji) {
    var label = (vibeName ?? '').trim();
    if (label.contains(emoji)) {
      label = label.replaceAll(emoji, '').trim();
    }
    if (label.isEmpty) return null;
    return label.length > 16 ? '${label.substring(0, 15)}…' : label;
  }

  VibeStyle _styleForCustomEmoji(String emoji) {
    final aiLabel = _aiVibeLabels[emoji];
    if (aiLabel != null && aiLabel.isNotEmpty) {
      return VibeStyle(
        label: aiLabel,
        emoji: emoji,
        softBg: SquadColors.mutedBg,
        softFg: SquadColors.text,
      );
    }
    final mapped = vibeStyleForEmoji(emoji);
    if (mapped.label.isNotEmpty) return mapped;
    return VibeStyle(
      label: 'Custom',
      emoji: emoji,
      softBg: SquadColors.mutedBg,
      softFg: SquadColors.text,
    );
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
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.secondary,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: SquadColors.primary.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CreatePhotoThumb extends StatelessWidget {
  const _CreatePhotoThumb({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<List<int>>(
        future: file.readAsBytes(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const ColoredBox(color: SquadColors.inputFill);
          }
          return Image.memory(
            Uint8List.fromList(snap.data!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      );
    }
    return Image.file(File(file.path), fit: BoxFit.cover);
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

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? SquadColors.primary.withValues(alpha: 0.15)
          : SquadColors.mutedBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? SquadColors.primary : SquadColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout `create.tsx` — custom minutes input with a stepper for "How long".
class _CustomDurationField extends StatelessWidget {
  const _CustomDurationField({
    required this.controller,
    required this.onChanged,
    required this.onStep,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SquadColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 18, color: SquadColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: onChanged,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DurationStepButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => onStep(5),
              ),
              _DurationStepButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => onStep(-5),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            'minutes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SquadColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationStepButton extends StatelessWidget {
  const _DurationStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SquadColors.card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Icon(icon, size: 18, color: SquadColors.muted),
        ),
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

/// Layout `create.tsx` — full-screen overlay while plan is posting.
