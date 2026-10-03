import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/model_provider.dart';

/// Initializes catalog configuration without changing selected voices or keys.
Future<void> migrateSpeechVoiceCatalog(DatabaseExecutor db) async {
  final rows = await db.query(
    'app_state',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
  if (rows.isEmpty) return;
  final settings =
      jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
  for (final entry in (settings['profiles'] as Map).entries) {
    final profile = entry.value as Map;
    final details = profile['providerDetails'] as Map?;
    final speech = details?['speechApi'] as Map?;
    if (speech == null) continue;
    final presets = [
      for (final service in ModelService.values)
        if (service.defaultSpeechApi case final preset?)
          if (preset.baseUrl == speech['baseUrl'] &&
              preset.path == speech['path'])
            preset,
    ];
    final preset = presets.isEmpty ? null : presets.single;
    speech['voiceCatalog'] = {
      for (final voice in preset?.voiceCatalog ?? const [])
        voice.id: {'id': voice.id, 'name': voice.name},
      for (final voice in speech['voices'] as List) voice['id']: voice,
    }.values.toList();
    speech['autoSyncVoices'] = false;
    speech['voiceList'] = preset?.voiceList?.toJson();
  }
  await db.update(
    'app_state',
    {'value': jsonEncode(settings)},
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
}
