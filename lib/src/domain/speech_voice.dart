import 'speech_voice_details.dart';

class SpeechVoice {
  const SpeechVoice({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.details,
    this.previewText,
    this.previewUrl,
  });

  final String id, name;
  final String? avatarUrl;
  final SpeechVoiceDetails? details;
  final String? previewText, previewUrl;

  SpeechVoice renamed(String name) => SpeechVoice(
    id: id,
    name: name,
    avatarUrl: avatarUrl,
    details: details,
    previewText: previewText,
    previewUrl: previewUrl,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'details': details?.toJson(),
    'previewText': previewText,
    'previewUrl': previewUrl,
  };

  factory SpeechVoice.fromJson(Map row) => SpeechVoice(
    id: row['id'] as String,
    name: row['name'] as String,
    avatarUrl: row['avatarUrl'] as String?,
    previewText: row['previewText'] as String?,
    previewUrl: row['previewUrl'] as String?,
    details: row['details'] == null
        ? null
        : SpeechVoiceDetails.fromJson(row['details'] as Map),
  );
}
