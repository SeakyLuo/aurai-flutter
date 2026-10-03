import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// A single speech owner across voice previews and message readouts.
class SpeechAudioPlayback {
  SpeechAudioPlayback({required this.onStop});

  static SpeechAudioPlayback? _active;
  final void Function() onStop;
  final _player = AudioPlayer();
  bool stopped = false;

  Future<void> acquire() async {
    final previous = _active;
    _active = this;
    if (previous != null) await previous.stop();
    if (stopped) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  Future<void> playFiles(
    List<String> paths, {
    required void Function() onStarted,
    void Function(Duration position, Duration duration)? onProgress,
  }) async {
    final durations = <Duration>[];
    var total = Duration.zero;
    if (onProgress != null) {
      for (final path in paths) {
        if (stopped) return;
        final duration = await _player.setFilePath(path);
        if (stopped) return;
        if (duration == null) throw StateError('无法读取试听音频时长');
        durations.add(duration);
        total += duration;
      }
    }
    var completed = Duration.zero;
    var reported = Duration.zero;
    void report(Duration position) {
      // Speech has no seeking: startup clock corrections must not rewind the ring.
      if (stopped || position < reported) return;
      reported = position;
      onProgress?.call(position, total);
    }

    for (var index = 0; index < paths.length; index++) {
      if (stopped) return;
      if (onProgress == null || paths.length > 1) {
        await _player.setFilePath(paths[index]);
      }
      if (stopped) return;
      final segmentStart = completed;
      if (onProgress != null) report(segmentStart);
      final positions = onProgress == null
          ? null
          : _player.positionStream.listen((position) {
              final duration = durations[index];
              report(
                segmentStart + (position > duration ? duration : position),
              );
            });
      final failure = Completer<void>();
      final errors = _player.errorStream.listen((error) {
        if (!failure.isCompleted) failure.completeError(error);
      });
      try {
        onStarted();
        await Future.any<void>([_player.play(), failure.future]);
        if (stopped) return;
        if (_player.processingState != ProcessingState.completed) {
          await stop();
          return;
        }
        if (onProgress != null) {
          completed += durations[index];
          report(completed);
        }
        await _player.pause();
      } finally {
        await positions?.cancel();
        await errors.cancel();
      }
    }
  }

  Future<void> stop() async {
    stopped = true;
    onStop();
    if (identical(_active, this)) _active = null;
    await _player.stop();
  }

  Future<void> dispose() async {
    if (identical(_active, this)) _active = null;
    await _player.dispose();
  }
}
