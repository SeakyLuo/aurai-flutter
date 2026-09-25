part of 'chat_controller.dart';

extension MusicGenerationActions on ChatController {
  Future<void> _loadMusicGeneration() async {
    final rows = await _store.database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['music_generation'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      musicGeneration = MusicGenerationConfig.fromJson(
        jsonDecode(rows.single['value'] as String) as Map<String, dynamic>,
      );
    }
  }

  Future<void> saveMusicGeneration(MusicGenerationConfig value) async {
    await _store.writer.mutate(() async {
      await _store.database.rawInsert(
        'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['music_generation', jsonEncode(value.toJson())],
      );
      musicGeneration = value;
    });
    _conversationChanged();
  }

  Future<Map<String, Object?>> _generateMusic(
    Map<String, Object?> args,
    MusicGenerationClient client,
    Conversation conversation,
    String senderId,
  ) async {
    final config = musicGeneration;
    if (config == null || config.apiKey.isEmpty) {
      final navigate = openAppPage;
      if (navigate != null) await navigate({'page': 'musicGeneration'});
      return {
        'generated': false,
        'needsConfiguration': true,
        'instruction': '请用户在模型设置 → 音乐生成中配置第三方 Suno API 密钥，完成前不要重复调用。',
      };
    }
    final prompt = (args['prompt'] as String).trim();
    final title = (args['title'] as String).trim();
    if (prompt.isEmpty || prompt.length > 1000)
      throw ArgumentError('音乐描述需为 1–1000 字');
    if (title.isEmpty || title.length > 100)
      throw ArgumentError('歌曲名称需为 1–100 字');
    final generated = await client.generate(
      key: config.apiKey,
      prompt: prompt,
      title: title,
      instrumental: args['instrumental'] as bool,
    );
    final files = <MessageFile>[];
    final downloadedPaths = <String>[];
    var sent = false;
    try {
      for (var index = 0; index < generated.songs.length; index++) {
        if (client.cancelled) throw const AgentCancelled();
        final path =
            '${_imageStore.directory}/${DateTime.now().microsecondsSinceEpoch}_$index.mp3';
        final file = File(path);
        downloadedPaths.add(path);
        final size = await client.download(
          generated.songs[index].audioUrl,
          file,
        );
        files.add(
          MessageFile(
            path: path,
            name: '$title ${index + 1}.mp3',
            mimeType: 'audio/mpeg',
            size: size,
          ),
        );
      }
      if (client.cancelled) throw const AgentCancelled();
      final output = await _sendPrivateGroupMessage(
        {
          'groupId': conversation.id,
          'message': {
            'text': generated.failedCount == 0
                ? '已生成《$title》的两个版本，点击音频文件播放。'
                : '已生成《$title》的一个版本，另一版本生成失败。点击音频文件播放。',
            '_images': <MessageImage>[],
            '_files': files,
            'mentionIds': <String>[],
          },
          'participation': 'unchanged',
        },
        senderId,
        requireGroup: false,
        sourceId: conversation.id,
      );
      sent = output['sent'] == true;
      return {
        'generated': true,
        'sent': sent,
        'count': files.length,
        'failedCount': generated.failedCount,
        'instruction': '音频已经作为会话附件发送，不要重复发送。',
      };
    } finally {
      if (!sent) {
        for (final path in downloadedPaths) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    }
  }
}
