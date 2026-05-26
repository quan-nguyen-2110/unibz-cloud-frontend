// Migrated from squadUp-layout/src/routes/create.tsx VoiceDictateDialog (commit 6bc7b3b)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/vibe_catalog.dart';
import '../theme/squad_theme.dart';

/// Parsed voice mock — fills the create form when user taps "Use this".
class VoiceDictateSample {
  const VoiceDictateSample({
    required this.text,
    required this.vibe,
    required this.when,
    required this.location,
    required this.people,
  });

  final String text;
  final SquadVibe vibe;
  final String when;
  final String location;
  final int people;
}

const _mockTranscripts = [
  VoiceDictateSample(
    text:
        'Hoops at Riverside Courts tonight, bring water — looking for 4 people.',
    vibe: SquadVibe.hoops,
    when: 'Tonight',
    location: 'Riverside Courts',
    people: 4,
  ),
  VoiceDictateSample(
    text: 'Chill coffee and study sesh at The Beanery this afternoon for 2.',
    vibe: SquadVibe.cafe,
    when: 'Today, 2:00 PM',
    location: 'The Beanery',
    people: 2,
  ),
  VoiceDictateSample(
    text:
        'Mario Kart tourney at my place tonight, snacks on me — squad of 6.',
    vibe: SquadVibe.gaming,
    when: 'Tonight',
    location: 'My Place',
    people: 6,
  ),
  VoiceDictateSample(
    text: 'Sunset pool laps at City View Pool in an hour, need 4 swimmers.',
    vibe: SquadVibe.swim,
    when: 'In 1 hour',
    location: 'City View Pool',
    people: 4,
  ),
];

enum _VoicePhase { idle, recording, transcribing, ready }

/// UI-only voice dictation (cycles mock transcripts). Returns sample on "Use this".
Future<VoiceDictateSample?> showVoiceDictateDialog(BuildContext context) {
  return showDialog<VoiceDictateSample>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _VoiceDictateDialog(),
  );
}

class _VoiceDictateDialog extends StatefulWidget {
  const _VoiceDictateDialog();

  @override
  State<_VoiceDictateDialog> createState() => _VoiceDictateDialogState();
}

class _VoiceDictateDialogState extends State<_VoiceDictateDialog> {
  _VoicePhase _phase = _VoicePhase.idle;
  int _elapsed = 0;
  int _sampleIdx = 0;
  String _shown = '';
  Timer? _elapsedTimer;
  Timer? _typeTimer;

  VoiceDictateSample get _sample => _mockTranscripts[_sampleIdx];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _clearTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _typeTimer?.cancel();
    _typeTimer = null;
  }

  void _startRecording() {
    _clearTimers();
    setState(() {
      _phase = _VoicePhase.recording;
      _elapsed = 0;
      _shown = '';
      _sampleIdx = (_sampleIdx + 1) % _mockTranscripts.length;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _stopRecording() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    setState(() => _phase = _VoicePhase.transcribing);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _phase = _VoicePhase.ready);
      var i = 0;
      _typeTimer = Timer.periodic(const Duration(milliseconds: 25), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        i += 2;
        setState(() => _shown = _sample.text.substring(0, i.clamp(0, _sample.text.length)));
        if (i >= _sample.text.length) {
          t.cancel();
          _typeTimer = null;
        }
      });
    });
  }

  String get _timeLabel {
    final mm = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (_elapsed % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: SquadColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tell us the plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Say something like “Hoops at Riverside Courts tonight with 4 people.”',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: SquadColors.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_phase == _VoicePhase.recording) ...[
                    _PulseRing(size: 96, opacity: 0.25),
                    _PulseRing(size: 112, opacity: 0.12),
                  ],
                  Material(
                    color: _phase == _VoicePhase.recording
                        ? SquadColors.danger
                        : SquadColors.primary,
                    shape: const CircleBorder(),
                    elevation: 6,
                    shadowColor: SquadColors.primary.withValues(alpha: 0.35),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (_phase == _VoicePhase.recording) {
                          _stopRecording();
                        } else {
                          _startRecording();
                        }
                      },
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Icon(
                          _phase == _VoicePhase.recording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: _phase == _VoicePhase.recording ? 32 : 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Waveform(active: _phase == _VoicePhase.recording),
            const SizedBox(height: 10),
            Text(
              switch (_phase) {
                _VoicePhase.recording => 'Listening • $_timeLabel',
                _VoicePhase.transcribing => 'Transcribing…',
                _VoicePhase.ready => 'Recorded • $_timeLabel',
                _ => 'Tap mic to start',
              },
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SquadColors.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 92),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SquadColors.mutedBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _phase == _VoicePhase.ready || _shown.isNotEmpty
                    ? _shown
                    : _phase == _VoicePhase.transcribing
                        ? 'Turning your voice into text…'
                        : 'Your words will appear here…',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.45,
                  color: _phase == _VoicePhase.ready || _shown.isNotEmpty
                      ? SquadColors.text
                      : SquadColors.muted,
                  fontStyle: _shown.isEmpty && _phase != _VoicePhase.ready
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                ),
                const Spacer(),
                if (_phase == _VoicePhase.ready)
                  OutlinedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Redo'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _phase == _VoicePhase.ready
                      ? () => Navigator.of(context).pop(_sample)
                      : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Use this'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + _controller.value * 0.15;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SquadColors.danger.withValues(alpha: widget.opacity),
            ),
          ),
        );
      },
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(18, (i) {
          final h = active ? 8.0 + ((i * 13) % 75) / 100 * 24 : 6.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: h,
              decoration: BoxDecoration(
                color: active
                    ? SquadColors.danger
                    : SquadColors.muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
