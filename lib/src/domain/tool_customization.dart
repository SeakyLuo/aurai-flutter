import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'tool_models.dart';

class ToolCustomization {
  const ToolCustomization({
    required this.title,
    required this.icon,
    required this.description,
    required this.inputSchema,
  });
  final String title, icon, description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => {
    'title': title,
    'icon': icon,
    'description': description,
    'inputSchema': inputSchema,
  };

  factory ToolCustomization.fromJson(Map<String, Object?> json) =>
      ToolCustomization(
        title: json['title'] as String,
        icon: json['icon'] as String,
        description: json['description'] as String,
        inputSchema: (json['inputSchema'] as Map).cast<String, Object?>(),
      );
}

abstract final class ToolCustomizations {
  static final values = <String, ToolCustomization>{};
  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('tool_customizations');
    values.clear();
    if (saved != null) {
      (jsonDecode(saved) as Map).forEach((key, value) {
        values[key as String] = ToolCustomization.fromJson(
          (value as Map).cast<String, Object?>(),
        );
      });
    }
  }

  static Future<void> save(String name, ToolCustomization value) async {
    final next = {...values, name: value};
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      'tool_customizations',
      jsonEncode({
        for (final entry in next.entries) entry.key: entry.value.toJson(),
      }),
    ))
      throw StateError('保存工具失败');
    values[name] = value;
  }

  static ToolDefinition apply(ToolDefinition tool) {
    final value = values[tool.name];
    if (value == null) return tool;
    return ToolDefinition(
      name: tool.name,
      description: value.description,
      inputSchema: value.inputSchema,
      safety: tool.safety,
      capabilityId: tool.capabilityId,
      actionArgument: tool.actionArgument,
      actionSafety: tool.actionSafety,
      executionTimeout: tool.executionTimeout,
      confirmationDescription: tool.confirmationDescription,
      confirmationDescriptionBuilder: tool.confirmationDescriptionBuilder,
      taskScopedConfirmation: tool.taskScopedConfirmation,
      confirmationMayBeRequired: tool.confirmationMayBeRequired,
      waitsForUser: tool.waitsForUser,
    );
  }
}
