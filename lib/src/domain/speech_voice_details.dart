class SpeechVoiceDetails {
  static const languageNames = {
    'zh-cn': '普通话',
    'en': '英语',
    'en-us': '英语',
    'ja': '日语',
    'ko': '韩语',
    'id': '印尼语',
    'es': '西班牙语',
    'es-mx': '西班牙语',
    'pt-br': '葡萄牙语',
    'de': '德语',
    'fr': '法语',
    'ru': '俄语',
    'it': '意大利语',
    'ar': '阿拉伯语',
    'hi': '印地语',
    'th': '泰语',
    'vi': '越南语',
  };
  const SpeechVoiceDetails(this.tags, this.description, {this.gender});
  final List<String> tags;
  final String description;
  final String? gender;

  Map<String, Object?> toJson() => {
    'tags': tags,
    'description': description,
    'gender': gender,
  };
  factory SpeechVoiceDetails.fromJson(Map json) => SpeechVoiceDetails(
    List<String>.from(json['tags'] as List),
    json['description'] as String,
    gender: json['gender'] as String?,
  );
}

// Descriptions follow the provider's voice catalogue. Unpublished age/style
// metadata is intentionally omitted rather than inferred from a voice name.
// https://www.alibabacloud.com/help/en/model-studio/qwen-tts-voice-list
// Preset details live in SpeechModels; remote details use response mappings.
