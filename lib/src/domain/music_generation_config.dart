class MusicGenerationConfig {
  const MusicGenerationConfig({required this.apiKey});

  static const serviceName = 'Suno API 平台（第三方）';
  static const baseUrl = 'https://open.suno.cn/api/v1';

  final String apiKey;

  Map<String, Object?> toJson() => {'apiKey': apiKey};

  factory MusicGenerationConfig.fromJson(Map<String, Object?> json) =>
      MusicGenerationConfig(apiKey: json['apiKey'] as String);
}
