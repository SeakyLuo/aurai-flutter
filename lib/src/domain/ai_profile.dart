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
    this.modelSelection,
    this.isTemporary = false,
  });
  final MessageSender sender;
  final bool isTemporary;
  final String description;
  final String instructions;
  // Null explicitly means following the application's current model settings.
  final AiModelSelection? modelSelection;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AiProfile.fromRows(
    MessageSender sender,
    Map<String, Object?> row,
  ) => AiProfile(
    sender: sender,
    isTemporary: row['is_temporary'] == 1,
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
