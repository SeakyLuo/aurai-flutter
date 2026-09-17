import '../agent/system_prompt.dart';
import 'response_preferences.dart';
import 'model_reasoning.dart';

class AiPreferences {
  const AiPreferences({
    this.systemPrompt = agentSystemPrompt,
    this.customInstructions = '',
    this.responses = const ResponsePreferences(),
    this.screenAccess = false,
    this.reasoning = ModelReasoning.inherit,
  });
  final String systemPrompt, customInstructions;
  final ResponsePreferences responses;
  final bool screenAccess;
  final ModelReasoning reasoning;
  AiPreferences copyWith({bool? screenAccess, ModelReasoning? reasoning}) =>
      AiPreferences(
        systemPrompt: systemPrompt,
        customInstructions: customInstructions,
        responses: responses,
        screenAccess: screenAccess ?? this.screenAccess,
        reasoning: reasoning ?? this.reasoning,
      );
  Map<String, Object?> toJson() => {
    'systemPrompt': systemPrompt,
    'customInstructions': customInstructions,
    'responses': responses.toJson(),
    'screenAccess': screenAccess,
    'reasoning': reasoning.name,
  };
  factory AiPreferences.fromJson(Map<String, dynamic> json) => AiPreferences(
    systemPrompt: json['systemPrompt'] as String,
    customInstructions: json['customInstructions'] as String,
    responses: ResponsePreferences.fromJson(
      Map<String, dynamic>.from(json['responses'] as Map),
    ),
    screenAccess: json['screenAccess'] as bool? ?? false,
    reasoning: ModelReasoning.values.byName(
      json['reasoning'] as String? ?? 'inherit',
    ),
  );
}
