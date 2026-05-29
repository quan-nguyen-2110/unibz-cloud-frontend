import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../data/vibe_catalog.dart';
import '../repositories/api_voice_repository.dart';
import '../services/api_client.dart';
import '../theme/squad_theme.dart';

/// Parsed voice mock — fills the create form when user taps "Use this".
class VoiceDictateSample {
  const VoiceDictateSample({
    required this.text,
    required this.title,
    required this.description,
    required this.vibeEmoji,
    this.vibeName,
    required this.vibe,
    required this.startAt,
    required this.location,
    required this.people,
    this.durationMinutes,
  });

  final String text;
  final String title;
  final String description;
  final String vibeEmoji;
  final String? vibeName;
  final SquadVibe vibe;
  final DateTime startAt;
  final String location;
  final int people;

  /// Estimated event length in minutes, or null when the AI didn't detect one.
  final int? durationMinutes;
}

enum _VoicePhase { idle, parsing, error }

/// Transcript-based voice parsing dialog (no mock transcript data).
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
  final _transcript = TextEditingController();
  final _repo = ApiVoiceRepository();
  final _speech = stt.SpeechToText();
  String? _errorText;
  int _seconds = 0;
  Timer? _clock;
  bool _speechReady = false;
  /// User tapped mic to record; only cleared when they tap stop.
  bool _recordingActive = false;
  /// True while the native recognizer is actively listening.
  bool _isListening = false;
  /// Text committed before the current recognition segment.
  String _committedPrefix = '';
  /// Words from the current segment (partial or final).
  String _segmentWords = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _speech.stop();
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' && _recordingActive) {
            _commitSegment();
            setState(() => _isListening = false);
            // Auto-pause from silence: keep recording and start a new segment.
            if (_recordingActive) {
              Future<void>.delayed(const Duration(milliseconds: 200), () {
                if (!mounted || !_recordingActive || _isListening) return;
                _beginListenSegment();
              });
            }
          } else if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _phase = _VoicePhase.error;
            _errorText = 'Microphone not available. You can still type transcript.';
            _isListening = false;
          });
        },
      );
      if (!mounted) return;
      setState(() => _speechReady = available);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _phase = _VoicePhase.error;
        _errorText =
            'Voice plugin not loaded yet. Fully restart the app (stop + flutter run).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechReady = false;
        _phase = _VoicePhase.error;
        _errorText = 'Could not initialize microphone. You can still type transcript.';
      });
    }
  }

  void _startClock() {
    _clock?.cancel();
    _seconds = 0;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _commitSegment() {
    _mergeSegmentIntoCommitted(_segmentWords);
    _segmentWords = '';
    _syncTranscriptField();
  }

  /// Avoid doubling when STT returns cumulative text across pause/resume.
  void _mergeSegmentIntoCommitted(String segment) {
    final s = segment.trim();
    if (s.isEmpty) return;
    final c = _committedPrefix.trim();
    if (c.isEmpty) {
      _committedPrefix = s;
      return;
    }
    if (s == c || c.endsWith(s)) return;
    if (s.startsWith(c)) {
      _committedPrefix = s;
      return;
    }
    _committedPrefix = '$c $s';
  }

  void _syncTranscriptField() {
    final c = _committedPrefix.trim();
    final s = _segmentWords.trim();
    if (c.isEmpty) {
      _transcript.text = s;
      return;
    }
    if (s.isEmpty) {
      _transcript.text = c;
      return;
    }
    if (s.startsWith(c)) {
      _transcript.text = s;
    } else if (c.endsWith(s)) {
      _transcript.text = c;
    } else {
      _transcript.text = '$c $s';
    }
  }

  Future<void> _parseTranscript() async {
    if (_recordingActive) {
      await _stopListening();
    } else {
      // Typed/pasted input path: do not let stale STT buffers overwrite text.
      _committedPrefix = _transcript.text.trim();
      _segmentWords = '';
    }
    final text = _transcript.text.trim();
    if (text.isEmpty) {
      setState(() {
        _phase = _VoicePhase.error;
        _errorText = 'Say or paste something first.';
      });
      return;
    }
    setState(() {
      _phase = _VoicePhase.parsing;
      _errorText = null;
    });
    try {
      final generated = await _repo.generatePlan(text);
      if (!mounted) return;
      final vibe = squadVibeFromEmoji(generated.vibeEmoji) ??
          _fallbackVibe('${generated.title} ${generated.description}');
      Navigator.of(context).pop(
        VoiceDictateSample(
          text: text,
          title: generated.title,
          description: generated.description.isEmpty ? text : generated.description,
          vibeEmoji: generated.vibeEmoji,
          vibeName: generated.vibeName,
          vibe: vibe,
          startAt: generated.startAt,
          location: (generated.location?.trim().isNotEmpty ?? false)
              ? generated.location!.trim()
              : 'TBD',
          people: generated.maxPeople < 0 ? -1 : generated.maxPeople.clamp(2, 30),
          durationMinutes: generated.durationMinutes,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) return;
      setState(() {
        _phase = _VoicePhase.error;
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _VoicePhase.error;
        _errorText = 'Could not parse your voice plan. Check backend/OpenRouter config.';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_phase == _VoicePhase.parsing) return;
    if (_recordingActive) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      setState(() {
        _phase = _VoicePhase.error;
        _errorText = 'Please allow microphone permission to auto-fill transcript.';
      });
      return;
    }
    final startingFresh = !_recordingActive;
    setState(() {
      _errorText = null;
      _phase = _VoicePhase.idle;
      _recordingActive = true;
    });
    if (startingFresh) {
      _committedPrefix = _transcript.text.trim();
      _segmentWords = '';
    }
    _startClock();
    await _beginListenSegment();
  }

  Future<void> _beginListenSegment() async {
    if (!_recordingActive || !_speechReady) return;
    setState(() => _isListening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _segmentWords = result.recognizedWords;
          setState(_syncTranscriptField);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 10),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recordingActive = false;
        _isListening = false;
        _phase = _VoicePhase.error;
        _errorText = 'Could not continue listening. Tap mic to try again.';
      });
    }
  }

  Future<void> _stopListening() async {
    _recordingActive = false;
    await _speech.stop();
    _commitSegment();
    if (!mounted) return;
    setState(() => _isListening = false);
    _clock?.cancel();
    _clock = null;
  }

  String get _timeLabel {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  SquadVibe _fallbackVibe(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'basketball|soccer|football|tennis|run|gym|hoops|swim|pool').hasMatch(lower)) {
      return SquadVibe.hoops;
    }
    if (RegExp(r'coffee|cafe|brunch|dinner|lunch|pizza|food|restaurant').hasMatch(lower)) {
      return SquadVibe.cafe;
    }
    if (RegExp(r'study|library|homework|project|exam').hasMatch(lower)) {
      return SquadVibe.study;
    }
    if (RegExp(r'game|gaming|mario|fifa|xbox|playstation|ps5|switch').hasMatch(lower)) {
        return SquadVibe.gaming;
    }
    if (RegExp(r'party|club|dance|concert').hasMatch(lower)) return SquadVibe.party;
    if (RegExp(r'park|hike|trail|outdoor|outdoors').hasMatch(lower)) return SquadVibe.outdoors;
    if (RegExp(r'movie|cinema|film').hasMatch(lower)) return SquadVibe.movie;
    return SquadVibe.study;
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
              'Tap mic and speak. We auto-fill transcript, then parse with AI.',
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
                  if (_phase == _VoicePhase.parsing) ...[
                    _PulseRing(size: 96, opacity: 0.25),
                    _PulseRing(size: 112, opacity: 0.12),
                  ],
                  Material(
                    color: _phase == _VoicePhase.parsing
                        ? SquadColors.danger
                        : SquadColors.primary,
                    shape: const CircleBorder(),
                    elevation: 6,
                    shadowColor: SquadColors.primary.withValues(alpha: 0.35),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _toggleListening,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Icon(
                          _recordingActive ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: _isListening ? 32 : 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Waveform(active: _recordingActive),
            const SizedBox(height: 10),
            Text(
              switch (_phase) {
                _VoicePhase.parsing => 'Parsing with AI…',
                _VoicePhase.error => 'Parse failed',
                _ => !_speechReady
                    ? 'Enable mic permission to auto-fill'
                    : (_recordingActive
                        ? 'Listening • $_timeLabel (pauses are OK)'
                        : 'Tap mic to start listening'),
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
            TextField(
              controller: _transcript,
              maxLines: 4,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Transcript appears here while you speak…',
                counterText: '',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: SquadColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 78),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SquadColors.mutedBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _phase == _VoicePhase.parsing
                    ? 'Generating plan fields from transcript…'
                    : 'Tap "Use this" to parse transcript with AI.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.45,
                  color: SquadColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OverflowBar(
              spacing: 8,
              overflowSpacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              alignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _phase == _VoicePhase.parsing
                      ? null
                      : _parseTranscript,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
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
