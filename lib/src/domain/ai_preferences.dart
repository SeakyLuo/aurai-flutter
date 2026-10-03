import '../agent/system_prompt.dart';
import 'ai_speech_selection.dart';
import 'response_preferences.dart';
import 'model_reasoning.dart';
import 'profile_gender.dart';

class AiPreferences {
  const AiPreferences({
    this.systemPrompt = agentSystemPrompt,
    this.customInstructions = '',
    this.responses = const ResponsePreferences(),
    this.screenAccess = false,
    this.reasoning = ModelReasoning.inherit,
    this.speech,
    this.gender = ProfileGender.unknown,
  });
  final String systemPrompt, customInstructions;
  final ResponsePreferences responses;
  final bool screenAccess;
  final ModelReasoning reasoning;
  final AiSpeechSelection? speech;
  final ProfileGender gender;
  AiPreferences copyWith({
    bool? screenAccess,
    ModelReasoning? reasoning,
    AiSpeechSelection? speech,
    ProfileGender? gender,
  }) => AiPreferences(
    systemPrompt: systemPrompt,
    customInstructions: customInstructions,
    responses: responses,
    screenAccess: screenAccess ?? this.screenAccess,
    reasoning: reasoning ?? this.reasoning,
    speech: speech ?? this.speech,
    gender: gender ?? this.gender,
  );
  Map<String, Object?> toJson() => {
    'systemPrompt': systemPrompt,
    'customInstructions': customInstructions,
    'responses': responses.toJson(),
    'screenAccess': screenAccess,
    'reasoning': reasoning.name,
    'gender': gender.name,
    if (speech != null) 'speech': speech!.toJson(),
  };
  factory AiPreferences.fromJson(Map<String, dynamic> json) => AiPreferences(
    gender: ProfileGender.values.byName(json['gender'] as String? ?? 'unknown'),
    speech: json['speech'] == null
        ? null
        : AiSpeechSelection.fromJson(
            Map<String, dynamic>.from(json['speech'] as Map),
          ),
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
