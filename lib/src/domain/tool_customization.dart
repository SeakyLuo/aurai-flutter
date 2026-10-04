import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'tool_models.dart';
import 'resource_scope.dart';

class ToolCustomization {
  const ToolCustomization({
    this.title,
    required this.icon,
    this.description,
    this.inputSchema,
    this.scopes = const [],
  });

  final String? title;
  final String icon;
  final String? description;
  final Map<String, Object?>? inputSchema;
  final List<ResourceScope> scopes;

  factory ToolCustomization.fromRow(
    Map<String, Object?> row,
    List<ResourceScope> scopes,
  ) => ToolCustomization(
    title: row['title'] as String?,
    scopes: scopes,
    icon: row['icon']! as String,
    description: row['description'] as String?,
    inputSchema: row['input_schema_json'] == null
        ? null
        : (jsonDecode(row['input_schema_json']! as String) as Map)
              .cast<String, Object?>(),
  );

  Map<String, Object?> toRow(String name) => {
    'name': name,
    'title': title,
    'icon': icon,
    'description': description,
    'input_schema_json': inputSchema == null ? null : jsonEncode(inputSchema),
  };
}

abstract final class ToolCustomizations {
  static final values = <String, ToolCustomization>{};
  static late Database _database;

  static Future<void> initialize(Database database) async {
    _database = database;
    final snapshot = await Future.wait([
      database.query('tool_customizations'),
      database.query(
        'resource_scopes',
        where: 'resource_type = ?',
        whereArgs: ['tool'],
      ),
    ]);
    final rows = snapshot[0];
    final scopes = resourceScopeMap(snapshot[1]);
    values
      ..clear()
      ..addEntries(
        rows.map(
          (row) => MapEntry(
            row['name']! as String,
            ToolCustomization.fromRow(row, scopes[row['name']] ?? []),
          ),
        ),
      );
  }

  static Future<void> save(String name, ToolCustomization value) async {
    final row = value.toRow(name);
    await _database.transaction((txn) async {
      final updated = await txn.update(
        'tool_customizations',
        row,
        where: 'name = ?',
        whereArgs: [name],
      );
      if (updated == 0) await txn.insert('tool_customizations', row);
      await writeResourceScopes(txn, 'tool', name, value.scopes);
    });
    values[name] = value;
  }

  static bool availableIn(String name, String? groupId, {String? projectId}) =>
      matchesResourceScope(
        values[name]?.scopes ?? [],
        groupId,
        projectId: projectId,
      );

  static Future<List<Map<String, Object?>>> groups() => _database.query(
    'conversations',
    columns: ['id', 'title', 'project_id'],
    where: "kind = 'group'",
    orderBy: 'updated_at DESC',
  );

  static Future<List<Map<String, Object?>>> projects() => _database.query(
    'development_projects',
    columns: ['id', 'name'],
    orderBy: 'updated_at DESC',
  );

  static ToolDefinition apply(ToolDefinition tool) {
    final value = values[tool.name];
    if (value == null) return tool;
    return ToolDefinition(
      name: tool.name,
      description: value.description ?? tool.description,
      inputSchema: value.inputSchema ?? tool.inputSchema,
      safety: tool.safety,
      capabilityId: tool.capabilityId,
      actionArgument: tool.actionArgument,
      actionSafety: tool.actionSafety,
      executionTimeout: tool.executionTimeout,
      confirmationDescription: tool.confirmationDescription,
      confirmationDescriptionBuilder: tool.confirmationDescriptionBuilder,
      taskScopedConfirmation: tool.taskScopedConfirmation,
      confirmationMayBeRequired: tool.confirmationMayBeRequired,
      singleUseConfirmation: tool.singleUseConfirmation,
      waitsForUser: tool.waitsForUser,
      authorizationScope: tool.authorizationScope,
      authorizationLabel: tool.authorizationLabel,
    );
  }
}
