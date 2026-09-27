import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'tool_models.dart';

class ToolCustomization {
  const ToolCustomization({
    this.title,
    required this.icon,
    this.description,
    this.inputSchema,
  });

  final String? title;
  final String icon;
  final String? description;
  final Map<String, Object?>? inputSchema;

  factory ToolCustomization.fromRow(Map<String, Object?> row) =>
      ToolCustomization(
        title: row['title'] as String?,
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
    final rows = await database.query('tool_customizations');
    values
      ..clear()
      ..addEntries(
        rows.map(
          (row) =>
              MapEntry(row['name']! as String, ToolCustomization.fromRow(row)),
        ),
      );
  }

  static Future<void> save(String name, ToolCustomization value) async {
    await _database.insert(
      'tool_customizations',
      value.toRow(name),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    values[name] = value;
  }

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
    );
  }
}
