import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/model_provider.dart';

/// Version 78 consolidates the previously split accounts; no legacy services
/// remain in the model registry after this data migration.
Future<void> migrateSpeechProviders(DatabaseExecutor db) async {
  final state = await db.query(
    'app_state',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
  if (state.isEmpty) return;
  final data =
      jsonDecode(state.single['value'] as String) as Map<String, dynamic>;
  final profiles = data['profiles'] as Map<String, dynamic>;
  const aliases = {'qwenSpeech': 'qwen', 'doubaoSpeech': 'doubao'};
  for (final entry in aliases.entries) {
    final separate = profiles.remove(entry.key) as Map<String, dynamic>?;
    final service = ModelService.byName(entry.value);
    final main =
        (profiles[entry.value] ?? ModelConfig.defaults(service).toJson())
            as Map;
    final details =
        (main['providerDetails'] ??
                ProviderDetails(
                  name: service.label,
                  website: service.defaultWebsite,
                  protocol: service.defaultProtocol,
                ).toJson())
            as Map;
    final preset = service.defaultSpeechApi!;
    final speech = {
      ...preset.toJson(),
      ...?(separate?['providerDetails'] as Map?)?['speechApi'] as Map?,
    };
    speech['baseUrl'] = separate?['baseUrl'] ?? preset.baseUrl;
    speech['apiKey'] = separate?['apiKey'] ?? '';
    speech['useProviderKey'] =
        separate == null ||
            (separate['apiKey'] as String).isEmpty ||
            separate['apiKey'] == main['apiKey']
        ? entry.value == 'qwen'
        : false;
    if (details['autoSyncModels'] == false && separate != null) {
      details['models'] = <String>{
        ...List<String>.from(details['models'] as List),
        ...((separate['providerDetails'] as Map)['autoSyncModels'] == false
            ? List<String>.from(
                (separate['providerDetails'] as Map)['models'] as List,
              )
            : service.defaultModelCatalog.map((model) => model.id)),
      }.toList();
    }
    details['speechApi'] = separate != null
        ? speech
        : details['speechApi'] ?? speech;
    main['providerDetails'] = details;
    profiles[entry.value] = main;
  }
  for (final profile in profiles.values) {
    final speech = (profile['providerDetails'] as Map?)?['speechApi'] as Map?;
    if (speech != null) {
      speech.putIfAbsent('baseUrl', () => profile['baseUrl']);
      speech.putIfAbsent('useProviderKey', () => true);
      speech.putIfAbsent('apiKey', () => '');
    }
  }
  for (final selection in (data['modelDefaults'] as Map? ?? const {}).values) {
    if (aliases.containsKey(selection['service']))
      selection['service'] = aliases[selection['service']];
  }
  final rows = await db.query(
    'ai_profiles',
    columns: ['sender_id', 'preferences'],
  );
  final batch = db.batch();
  batch.update(
    'app_state',
    {'value': jsonEncode(data)},
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
  for (final row in rows) {
    final preferences =
        jsonDecode(row['preferences'] as String) as Map<String, dynamic>;
    final speech = preferences['speech'] as Map?;
    if (speech != null && aliases.containsKey(speech['service'])) {
      speech['service'] = aliases[speech['service']];
      batch.update(
        'ai_profiles',
        {'preferences': jsonEncode(preferences)},
        where: 'sender_id = ?',
        whereArgs: [row['sender_id']],
      );
    }
  }
  await batch.commit(noResult: true);
}
