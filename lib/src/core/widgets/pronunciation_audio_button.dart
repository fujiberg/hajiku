import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../wanikani/models/wanikani_subject.dart';

/// A button that plays a single [WaniKaniPronunciationAudio] clip, showing
/// the voice actor's name and toggling between a play and stop icon while
/// the clip is loading or playing.
class PronunciationAudioButton extends StatefulWidget {
  const PronunciationAudioButton({super.key, required this.audio});

  final WaniKaniPronunciationAudio audio;

  @override
  State<PronunciationAudioButton> createState() =>
      _PronunciationAudioButtonState();
}

class _PronunciationAudioButtonState extends State<PronunciationAudioButton> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await _player.play(UrlSource(widget.audio.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _toggle,
      icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
      label: Text(widget.audio.voiceActorName ?? 'Play audio'),
    );
  }
}
