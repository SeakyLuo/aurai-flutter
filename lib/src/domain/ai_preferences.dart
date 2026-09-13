import '../agent/system_prompt.dart';
import 'response_preferences.dart';

class AiPreferences {
  const AiPreferences({
    this.systemPrompt = agentSystemPrompt,
    this.customInstructions = '',
    this.responses = const ResponsePreferences(),
    this.screenAccess = false,
  });
  final String systemPrompt, customInstructions;
  final ResponsePreferences responses;
  final bool screenAccess;
  AiPreferences copyWith({bool? screenAccess}) => AiPreferences(
    systemPrompt: systemPrompt,
    customInstructions: customInstructions,
    responses: responses,
    screenAccess: screenAccess ?? this.screenAccess,
  );
  Map<String, Object?> toJson() => {
    'systemPrompt': systemPrompt,
    'customInstructions': customInstructions,
    'responses': responses.toJson(),
    'screenAccess': screenAccess,
  };
  factory AiPreferences.fromJson(Map<String, dynamic> json) => AiPreferences(
    systemPrompt: json['systemPrompt'] as String,
    customInstructions: json['customInstructions'] as String,
    responses: ResponsePreferences.fromJson(
      Map<String, dynamic>.from(json['responses'] as Map),
    ),
    screenAccess: json['screenAccess'] as bool? ?? false,
  );
}
