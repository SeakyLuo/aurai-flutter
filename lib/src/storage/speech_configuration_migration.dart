import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Moves credentials and model metadata into the common supplier configuration.
Future<void> migrateSpeechConfiguration(DatabaseExecutor db) async {
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
    if (details == null) continue;
    final speech = details['speechApi'] as Map?;
    final models = speech?.remove('models') as List? ?? const [];
    final credential = speech?.remove('apiKey') as String? ?? '';
    final useMain = speech?.remove('useProviderKey') as bool? ?? true;
    details['speechApiKey'] = useMain ? '' : credential;
    final catalog = <String, Map>{
      for (final model in details['modelCatalog'] as List? ?? const [])
        model['id'] as String: Map.from(model as Map),
      for (final model in models) model['id'] as String: Map.from(model as Map),
    };
    details['modelCatalog'] = catalog.values.toList();
    final purposes = details['modelPurposes'] as Map;
    for (final model in models) {
      purposes.putIfAbsent(model['id'], () => ['speechSynthesis']);
    }
  }
  await db.update(
    'app_state',
    {'value': jsonEncode(settings)},
    where: 'key = ?',
    whereArgs: ['model_config_json'],
  );
}
