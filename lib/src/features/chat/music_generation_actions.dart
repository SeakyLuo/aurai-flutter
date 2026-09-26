part of 'chat_controller.dart';

extension MusicGenerationActions on ChatController {
  Future<void> _migrateMusicGeneration() async {
    final rows = await _store.database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['music_generation'],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final old =
        jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
    final musicService = ModelService.values.firstWhere(
      (service) => service.defaultProtocol.defaultModelPurposes.contains(
        ModelPurpose.musicGeneration,
      ),
    );
    final account = modelSettings.profile(musicService);
    var next = modelSettings;
    if (!account.isConfigured) {
      next = ModelSettings(
        activeService: modelSettings.activeService,
        profiles: {
          ...modelSettings.profiles,
          musicService: account.copyWith(apiKey: old['apiKey'] as String),
        },
        systemPrompt: modelSettings.systemPrompt,
        customInstructions: modelSettings.customInstructions,
        responsePreferences: modelSettings.responsePreferences,
        modelDefaults: modelSettings.modelDefaults,
      );
    }
    await _store.database.transaction((txn) async {
      if (!account.isConfigured) {
        await txn.rawInsert(
          'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
          ['model_config_json', jsonEncode(next.toJson())],
        );
      }
      await txn.delete(
        'app_state',
        where: 'key = ?',
        whereArgs: ['music_generation'],
      );
    });
    modelSettings = next;
  }

  Future<Map<String, Object?>> _generateMusic(
    Map<String, Object?> args,
    MusicGenerationClient client,
    Conversation conversation,
    String senderId,
  ) async {
    final selection = modelSettings.firstAvailableMusicModel;
    if (selection == null) {
      final navigate = openAppPage;
      if (navigate != null) await navigate({'page': 'musicGeneration'});
      return {
        'generated': false,
        'needsConfiguration': true,
        'instruction': '请用户配置支持音乐生成的供应商和可用模型，完成前不要重复调用。',
      };
    }
    final config = selection.config;
    final prompt = (args['prompt'] as String).trim();
    final title = (args['title'] as String).trim();
    if (prompt.isEmpty || prompt.length > 1000)
      throw ArgumentError('音乐描述需为 1–1000 字');
    if (title.isEmpty || title.length > 100)
      throw ArgumentError('歌曲名称需为 1–100 字');
    final generated = await client.generate(
      key: config.apiKey,
      baseUrl: config.baseUrl,
      model: selection.model,
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
