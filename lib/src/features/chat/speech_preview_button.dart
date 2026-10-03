import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/ui_action.dart';
import '../../domain/model_provider.dart';
import '../../domain/speech_voice.dart';
import '../../domain/speech_preview_mode.dart';
import '../../providers/speech_synthesis_client.dart';
import '../../providers/model_purpose_catalog.dart';
import 'question_icon.dart';
import 'settings_icon.dart';

import 'speech_audio_playback.dart';

/// Shared idle/active preview control for single and multiple voice selection.
class SpeechVoicePreview extends StatelessWidget {
  const SpeechVoicePreview({
    super.key,
    required this.account,
    required this.voice,
    required this.mode,
    required this.text,
    required this.active,
    required this.enabled,
    required this.onActivate,
  });
  final ModelConfig account;
  final SpeechVoice voice;
  final SpeechPreviewMode mode;
  final String text;
  final bool active, enabled;
  final VoidCallback onActivate;
  @override
  Widget build(BuildContext context) {
    final previewText = mode == SpeechPreviewMode.providerText
        ? voice.previewText ?? ''
        : text;
    final previewUrl = mode == SpeechPreviewMode.providerAudio
        ? voice.previewUrl
        : null;
    final canPlay =
        enabled &&
        (mode == SpeechPreviewMode.providerAudio
            ? previewUrl?.isNotEmpty == true
            : account.isSpeechConfigured && previewText.trim().isNotEmpty);
    return active
        ? SpeechPreviewButton(
            key: ValueKey((
              voice.id,
              mode,
              previewText,
              previewUrl,
              account.model,
            )),
            account: account,
            voice: voice.id,
            text: previewText.trim(),
            previewUrl: previewUrl,
            enabled: canPlay,
            compact: true,
          )
        : SizedBox.square(
            dimension: 40,
            child: IconButton(
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                shape: const CircleBorder(),
              ),
              tooltip: '播放试听',
              onPressed: canPlay ? onActivate : null,
              icon: const SettingsIcon(type: SettingsIconType.play),
            ),
          );
  }
}

/// Keeps the generated sample for replay until the selected voice changes.
class SpeechPreviewButton extends StatefulWidget {
  const SpeechPreviewButton({
    super.key,
    required this.account,
    required this.voice,
    required this.text,
    required this.enabled,
    this.compact = false,
    this.previewUrl,
  });
  final ModelConfig account;
  final String voice, text;
  final String? previewUrl;
  final bool enabled;
  final bool compact;

  @override
  State<SpeechPreviewButton> createState() => _SpeechPreviewButtonState();
}

class _SpeechPreviewButtonState extends State<SpeechPreviewButton>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _client = SpeechSynthesisClient();
  final _sampleClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  final _files = <File>[];
  Directory? _directory;
  Future<void>? _operation;
  bool _loading = false, _playing = false, _stopped = false;
  SpeechAudioPlayback? _audio;
  int _position = 0, _duration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _tap();
    });
  }

  Future<void> _play() async {
    _stopped = false;
    setState(() {
      _loading = true;
      _position = 0;
      _duration = 0;
    });
    final audio = SpeechAudioPlayback(onStop: () => _stopped = true);
    _audio = audio;
    try {
      await audio.acquire();
      if (_stopped) return;
      _directory ??= await (await getTemporaryDirectory()).createTemp(
        'speech_preview_',
      );
      if (widget.previewUrl case final url?) {
        if (_files.isEmpty) {
          final uri = Uri.parse(url);
          final request = await _sampleClient.getUrl(uri);
          final response = await request.close().timeout(
            const Duration(seconds: 30),
          );
          if (response.statusCode != HttpStatus.ok) {
            throw ModelProviderException(
              response.reasonPhrase,
              statusCode: response.statusCode,
              detail: await utf8.decoder.bind(response).join(),
            );
          }
          final file = File(
            '${_directory!.path}/sample.${uri.path.split('.').last}',
          );
          await response
              .pipe(file.openWrite())
              .timeout(const Duration(seconds: 30));
          _files.add(file);
        }
      } else {
        final account = widget.account;
        if (!account.isSpeechConfigured) {
          throw StateError('请先配置语音供应商');
        }
        final api = account.speechApi!;
        if (!modelPurposesFor(
              account,
              account.model,
            ).contains(ModelPurpose.speechSynthesis) ||
            (!account.autoSyncModels &&
                !account.savedModels.contains(account.model)) ||
            (!api.autoSyncVoices &&
                !api.voices.any((voice) => voice.id == widget.voice))) {
          throw StateError('所选语音模型或音色已移除，请重新设置声音');
        }
        final segments = speechSegments(widget.text, api.maxCharacters);
        for (var index = 0; index < segments.length; index++) {
          if (_stopped) break;
          if (index >= _files.length) {
            final bytes = await _client
                .synthesize(account, widget.voice, segments[index])
                .timeout(const Duration(seconds: 90));
            if (_stopped) break;
            final file = File(
              '${_directory!.path}/$index.${api.fileExtension}',
            );
            await file.writeAsBytes(bytes);
            _files.add(file);
          }
        }
      }
      if (_stopped) return;
      await audio.playFiles(
        _files.map((file) => file.path).toList(),
        onStarted: () {
          if (mounted)
            setState(() {
              _loading = false;
              _playing = true;
            });
        },
        onProgress: (position, duration) {
          if (mounted)
            setState(() {
              _position = position.inMilliseconds;
              _duration = duration.inMilliseconds;
            });
        },
      );
    } on Object {
      // Disposing or replacing a preview cancels a pending plugin load.
      if (!_stopped) rethrow;
    } finally {
      await audio.dispose();
      _audio = null;
      if (mounted)
        setState(() {
          _loading = false;
          _playing = false;
        });
    }
  }

  Future<void> _stop() async {
    _stopped = true;
    await _audio?.stop();
  }

  void _tap() {
    if (_playing) {
      unawaited(runUiAction(context, _stop));
    } else {
      _operation = runUiAction(context, _play).then<void>((_) {});
    }
  }

  Future<void> _release() async {
    _stopped = true;
    _client.close();
    _sampleClient.close(force: true);
    await _audio?.stop();
    await _operation;
    if (_directory case final directory?)
      await directory.delete(recursive: true);
  }

  @override
  void dispose() {
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: widget.compact ? 40 : 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Semantics(
            value: _duration > 0
                ? '${_time(_position)} / ${_time(_duration)}'
                : null,
            child: IconButton(
              style: IconButton.styleFrom(
                fixedSize: Size.square(widget.compact ? 40 : 48),
                side: BorderSide(color: colors.outlineVariant),
                shape: const CircleBorder(),
              ),
              tooltip: _loading
                  ? widget.previewUrl == null
                        ? '正在生成试听'
                        : '正在加载试听'
                  : _playing
                  ? '停止试听'
                  : '播放试听',
              onPressed: widget.enabled && !_loading ? _tap : null,
              icon: _loading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.65,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : _playing
                  ? QuestionIcon(
                      type: QuestionIconType.stop,
                      color: colors.onSurface,
                    )
                  : SettingsIcon(
                      type: SettingsIconType.play,
                      color: colors.onSurface,
                    ),
            ),
          ),
          if (!_loading && _duration > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CircularProgressIndicator(
                  value: (_position / _duration).clamp(0.0, 1.0),
                  strokeWidth: 2,
                  strokeAlign: -1,
                  backgroundColor: Colors.transparent,
                  color: colors.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _time(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
