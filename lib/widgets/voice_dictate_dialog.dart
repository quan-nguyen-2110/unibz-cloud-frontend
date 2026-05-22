import 'dart:async';

import 'package:flutter/material.dart';

import '../data/vibe_catalog.dart';
import '../theme/squad_theme.dart';

/// Mock voice fill — `squadUp-layout` `create.tsx` MOCK_TRANSCRIPTS.
class VoiceDictateResult {
  const VoiceDictateResult({
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

const _mockTranscripts = <VoiceDictateResult>[
  VoiceDictateResult(
    text:
        'Hoops at Riverside Courts tonight, bring water — looking for 4 people.',
    vibe: SquadVibe.hoops,
    when: 'Tonight',
    location: 'Riverside Courts',
    people: 4,
  ),
  VoiceDictateResult(
    text:
        'Chill coffee and study sesh at The Beanery this afternoon for 2.',
    vibe: SquadVibe.cafe,
    when: 'Today, 2:00 PM',
    location: 'The Beanery',
    people: 2,
  ),
  VoiceDictateResult(
    text:
        'Mario Kart tourney at my place tonight, snacks on me — squad of 6.',
    vibe: SquadVibe.gaming,
    when: 'Tonight',
    location: 'My Place',
    people: 6,
  ),
  VoiceDictateResult(
    text:
        'Sunset pool laps at City View Pool in an hour, need 4 swimmers.',
    vibe: SquadVibe.swim,
    when: 'In 1 hour',
    location: 'City View Pool',
    people: 4,
  ),
];

Future<VoiceDictateResult?> showVoiceDictateDialog(BuildContext context) {
  return showDialog<VoiceDictateResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _VoiceDictateDialog(),
  );
}

class _VoiceDictateDialog extends StatefulWidget {
  const _VoiceDictateDialog();

  @override
  State<_VoiceDictateDialog> createState() => _VoiceDictateDialogState();
}

class _VoiceDictateDialogState extends State<_VoiceDictateDialog> {
  bool _recording = false;
  bool _done = false;
  int _sampleIndex = 0;
  String _liveText = '';
  VoiceDictateResult? _completedSample;
  Timer? _typeTimer;

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _done = false;
      _liveText = '';
    });
    _typeTimer?.cancel();
    final sample = _mockTranscripts[_sampleIndex % _mockTranscripts.length];
    _sampleIndex++;
    var i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i >= sample.text.length) {
        t.cancel();
        setState(() {
          _liveText = sample.text;
          _completedSample = sample;
          _recording = false;
          _done = true;
        });
        return;
      }
      i += 3;
      setState(() {
        _liveText = sample.text.substring(0, i.clamp(0, sample.text.length));
      });
    });
  }

  void _apply() {
    final sample = _completedSample;
    if (sample != null) Navigator.pop(context, sample);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Say your plan',
                    style: squadDisplay(context, 20),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Prototype dictation — tap the mic, then use what we heard.',
              style: TextStyle(color: SquadColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SquadColors.mutedBg,
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(minHeight: 88),
              child: Text(
                _liveText.isEmpty
                    ? (_recording ? 'Listening…' : 'Tap the mic to start')
                    : _liveText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: _liveText.isEmpty
                      ? SquadColors.muted
                      : SquadColors.text,
                  fontStyle:
                      _liveText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Material(
                color: _recording ? SquadColors.danger : SquadColors.primary,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recording
                      ? () {
                          _typeTimer?.cancel();
                          setState(() {
                            _recording = false;
                            _done = _liveText.isNotEmpty;
                          });
                        }
                      : _startRecording,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Icon(
                      _recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            if (_done) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _apply,
                child: const Text('Use this'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _done = false;
                    _liveText = '';
                  });
                  _startRecording();
                },
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
