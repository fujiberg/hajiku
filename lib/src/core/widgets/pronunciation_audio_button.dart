import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../resources/audio_resource_source.dart';
import '../resources/resource_providers.dart';
import '../wanikani/models/wanikani_subject.dart';

/// A button that plays a single [WaniKaniPronunciationAudio] clip, showing
/// the voice actor's name and toggling between a play and stop icon while
/// the clip is loading or playing.
///
/// Playback goes through the resource service: a cached clip plays instantly,
/// otherwise it's downloaded first. Tapping the button is an explicit,
/// user-initiated action, so it plays even on a metered connection.
class PronunciationAudioButton extends ConsumerStatefulWidget {
  const PronunciationAudioButton({super.key, required this.audio});

  final WaniKaniPronunciationAudio audio;

  @override
  ConsumerState<PronunciationAudioButton> createState() =>
      _PronunciationAudioButtonState();
}

class _PronunciationAudioButtonState
    extends ConsumerState<PronunciationAudioButton> {
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
      return;
    }

    setState(() => _isPlaying = true);
    final resource = await ref
        .read(resourceServiceProvider)
        .resolveAudio(widget.audio, userInitiated: true);
    if (!mounted) return;
    if (resource == null) {
      setState(() => _isPlaying = false);
      return;
    }
    await _player.play(resource.toSource());
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
