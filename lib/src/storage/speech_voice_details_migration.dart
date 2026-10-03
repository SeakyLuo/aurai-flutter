import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/model_provider.dart';

/// Adds voice detail mappings and preset metadata to existing configuration.
Future<void> migrateSpeechVoiceDetails(DatabaseExecutor db) async {
  final rows = await db.query(
    'app_state',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
  if (rows.isEmpty) return;
  final settings =
      jsonDecode(rows.single['value'] as String) as Map<String, dynamic>;
  for (final entry in (settings['profiles'] as Map).values) {
    final details = (entry as Map)['providerDetails'] as Map?;
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
    final voices = {
      for (final voice in preset?.voiceCatalog ?? const []) voice.id: voice,
    };
    for (final key in ['voices', 'voiceCatalog']) {
      for (final voice in speech[key] as List) {
        voice['details'] = voices[voice['id']]?.details?.toJson();
      }
    }
    final list = speech['voiceList'] as Map?;
    if (list != null) {
      final mapping = preset?.voiceList;
      final sameEndpoint = mapping?.url == list['url'];
      list['genderPath'] = sameEndpoint ? mapping!.genderPath : null;
      list['descriptionPath'] = sameEndpoint ? mapping!.descriptionPath : null;
      list['genderValues'] = sameEndpoint
          ? mapping!.genderValues
          : <String, String>{};
      list['tagPaths'] = sameEndpoint ? mapping!.tagPaths : <String>[];
    }
  }
  await db.update(
    'app_state',
    {'value': jsonEncode(settings)},
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
}
