import 'dart:convert';
import 'ai_preferences.dart';
export 'ai_preferences.dart';
import 'message_sender.dart';
import 'model_provider.dart';

// Credentials remain in model settings; an AI only stores its model selection.
class AiModelSelection {
  const AiModelSelection({
    required this.provider,
    required this.model,
    required this.baseUrl,
  });
  final ModelService provider;
  final String model;
  final String baseUrl;
}

class AiProfile {
  const AiProfile({
    required this.sender,
    required this.description,
    required this.instructions,
    required this.createdAt,
    required this.updatedAt,
    this.previousUpdatedAt,
    this.modelSelection,
    this.isTemporary = false,
    this.preferences = const AiPreferences(),
  });
  final MessageSender sender;
  final AiPreferences preferences;
  final bool isTemporary;
  final String description;
  final String instructions;
  // Legacy rows may be null while migrating; initialization fixes their model selection before use.
  final AiModelSelection? modelSelection;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? previousUpdatedAt;

  AiProfile copyWith({
    MessageSender? sender,
    String? description,
    String? instructions,
    AiModelSelection? modelSelection,
    AiPreferences? preferences,
    bool? isTemporary,
  }) => AiProfile(
    sender: sender ?? this.sender,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    modelSelection: modelSelection ?? this.modelSelection,
    preferences: preferences ?? this.preferences,
    isTemporary: isTemporary ?? this.isTemporary,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    previousUpdatedAt: updatedAt,
  );

  factory AiProfile.fromRows(
    MessageSender sender,
    Map<String, Object?> row,
  ) => AiProfile(
    sender: sender,
    isTemporary: row['is_temporary'] == 1,
    preferences: row['preferences'] == null
        ? const AiPreferences()
        : AiPreferences.fromJson(
            jsonDecode(row['preferences'] as String) as Map<String, dynamic>,
          ),
    description: row['description'] as String,
    instructions: row['instructions'] as String,
    modelSelection: row['provider'] == null
        ? null
        : AiModelSelection(
            provider: ModelService.values.byName(row['provider'] as String),
            model: row['model'] as String,
            baseUrl: row['base_url'] as String,
          ),
    createdAt: DateTime.fromMicrosecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(row['updated_at'] as int),
  );
}

class ConversationMember {
  const ConversationMember({
    required this.sender,
    required this.position,
    required this.joinedAt,
    this.leftAt,
  });
  final MessageSender sender;
  final int position;
  final DateTime joinedAt;
  final DateTime? leftAt;
}
