import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/model_provider.dart';
import '../../providers/speech_synthesis_client.dart';
import '../../providers/model_purpose_catalog.dart';
import 'ai_speech_page.dart';
import 'chat_controller.dart';
import 'speech_audio_playback.dart';

enum SpeechReadoutPhase { loading, playing }

final speechReadoutState =
    ValueNotifier<({Object key, SpeechReadoutPhase phase})?>(null);
_SpeechSession? _active;
var _request = 0;

Future<void> stopSpeechReadout(Object key) async {
  final session = _active;
  if (session == null || session.key != key) return;
  await session.stop();
}

Future<void> toggleSpeechReadout(
  BuildContext context, {
  required Object key,
  required ChatController controller,
  required String senderId,
  required String text,
}) async {
  final request = ++_request;
  final previous = _active;
  if (previous != null) {
    await previous.stop();
    if (request != _request) return;
    if (previous.key == key) return;
  }
  final session = _SpeechSession(key);
  _active = session;
  speechReadoutState.value = (key: key, phase: SpeechReadoutPhase.loading);
  try {
    await session.audio.acquire();
    if (session.stopped) return;
    var profile = await controller.groupStore.loadAi(senderId);
    if (session.stopped || !context.mounted) return;
    var voice = profile.preferences.speech;
    if (voice == null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AiSpeechPage(controller: controller, profile: profile),
        ),
      );
      profile = await controller.groupStore.loadAi(senderId);
      voice = profile.preferences.speech;
      if (session.stopped || !context.mounted || voice == null) return;
    }
    final account = controller.modelSettings.profile(voice.service);
    if (!account.isSpeechConfigured) {
      throw StateError('请在朋友的声音设置中配置语音供应商');
    }
    if (!modelPurposesFor(
          account,
          voice.model,
        ).contains(ModelPurpose.speechSynthesis) ||
        (!account.autoSyncModels &&
            !account.savedModels.contains(voice.model)) ||
        (!account.speechApi!.autoSyncVoices &&
            !account.speechApi!.voices.any(
              (item) => item.id == voice!.voice,
            ))) {
      throw StateError('所选语音模型或音色已移除，请重新设置声音');
    }
    final plain = text.trim();
    if (plain.isEmpty) throw StateError('这条消息没有可朗读的文字');
    await session.read(
      account.copyWith(model: voice.model),
      voice.voice,
      plain,
    );
  } on Object {
    // Closing the synthesis connection is how a user cancels loading.
    if (!session.stopped) rethrow;
  } finally {
    session.client.close();
    await session.audio.dispose();
    if (identical(_active, session)) {
      _active = null;
      speechReadoutState.value = null;
    }
  }
}

class _SpeechSession {
  _SpeechSession(this.key);
  final Object key;
  final client = SpeechSynthesisClient();
  bool stopped = false;
  late final audio = SpeechAudioPlayback(
    onStop: () {
      stopped = true;
      client.close();
      if (identical(_active, this)) {
        _active = null;
        speechReadoutState.value = null;
      }
    },
  );

  Future<void> read(ModelConfig account, String voice, String text) async {
    final api = account.speechApi!;
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/speech_cache',
    );
    await directory.create(recursive: true);
    await _trimCache(directory);
    if (stopped) return;
    final config = api.toJson();
    final files = <File>[];
    for (final segment in speechSegments(text, api.maxCharacters)) {
      if (stopped) return;
      final digest = sha256.convert(
        utf8.encode(
          jsonEncode([
            account.service.name,
            account.baseUrl,
            account.apiModel,
            voice,
            config,
            segment,
          ]),
        ),
      );
      final file = File('${directory.path}/$digest.${api.fileExtension}');
      if (!await file.exists()) {
        final bytes = await client
            .synthesize(account, voice, segment)
            .timeout(const Duration(seconds: 90));
        if (stopped) return;
        final pending = File('${file.path}.${identityHashCode(this)}.part');
        await pending.writeAsBytes(bytes, flush: true);
        await pending.rename(file.path);
      }
      files.add(file);
    }
    if (stopped) return;
    await audio.playFiles(
      files.map((file) => file.path).toList(),
      onStarted: () => speechReadoutState.value = (
        key: key,
        phase: SpeechReadoutPhase.playing,
      ),
    );
  }

  Future<void> stop() => audio.stop();
}

Future<void> _trimCache(Directory directory) async {
  final entries = <({File file, FileStat stat})>[];
  await for (final entry in directory.list()) {
    if (entry is File) entries.add((file: entry, stat: await entry.stat()));
  }
  entries.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
  var size = 0;
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    size += entry.stat.size;
    if (index >= 128 ||
        size > 64 * 1024 * 1024 ||
        DateTime.now().difference(entry.stat.modified).inDays >= 7) {
      await entry.file.delete();
    }
  }
}
