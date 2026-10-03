import 'speech_voice_list_config.dart';
import 'speech_voice.dart';

enum SpeechResponseFormat { json, jsonLines }

enum SpeechAudioEncoding { url, base64 }

class SpeechApiConfig {
  const SpeechApiConfig({
    required this.path,
    required this.authHeader,
    this.authPrefix = '',
    this.baseUrl = '',
    required this.modelPath,
    required this.textPath,
    required this.voicePath,
    required this.audioPath,
    required this.audioEncoding,
    required this.fileExtension,
    this.responseFormat = SpeechResponseFormat.json,
    this.modelHeader = '',
    this.body = const {},
    this.headers = const {},
    this.codePath = '',
    this.successCodes = const [],
    this.completionCode,
    this.maxCharacters = 500,
    this.voices = const [],
    this.voiceCatalog = const [],
    this.autoSyncVoices = false,
    this.voiceList,
  });
  final String path, authHeader, authPrefix, modelPath, textPath, voicePath;
  final String audioPath, fileExtension, modelHeader, codePath;
  final String baseUrl;
  final SpeechResponseFormat responseFormat;
  final SpeechAudioEncoding audioEncoding;
  final Map<String, Object?> body;
  final Map<String, String> headers;
  final List<Object?> successCodes;
  final Object? completionCode;
  final int maxCharacters;
  final List<SpeechVoice> voices;
  final List<SpeechVoice> voiceCatalog;
  final bool autoSyncVoices;
  final SpeechVoiceListConfig? voiceList;

  List<SpeechVoice> orderVoices(List<SpeechVoice> available) {
    final remaining = {for (final voice in available) voice.id: voice};
    return [
      for (final voice in voices)
        if (remaining.containsKey(voice.id)) remaining.remove(voice.id)!,
      ...remaining.values,
    ];
  }

  void validate() {
    if (baseUrl.isNotEmpty) {
      final base = Uri.tryParse(baseUrl);
      if (base == null ||
          base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          base.hasQuery ||
          base.hasFragment) {
        throw ArgumentError('请填写有效的 HTTPS 语音服务地址');
      }
    }
    final endpoint = Uri.tryParse(path);
    if (path.isEmpty ||
        endpoint == null ||
        endpoint.hasScheme ||
        path.startsWith('/') ||
        endpoint.hasFragment) {
      throw ArgumentError('语音接口路径需为相对于服务地址的路径');
    }
    if (authHeader.isEmpty ||
        textPath.isEmpty ||
        voicePath.isEmpty ||
        audioPath.isEmpty ||
        (modelPath.isEmpty && modelHeader.isEmpty) ||
        maxCharacters < 1 ||
        maxCharacters > 10000 ||
        !RegExp(r'^[a-z0-9]+$').hasMatch(fileExtension)) {
      throw ArgumentError('请完整配置语音接口、模型和音色');
    }
    for (final list in [voices, voiceCatalog]) {
      if (list.any((entry) => entry.id.isEmpty || entry.name.isEmpty) ||
          list.map((entry) => entry.id).toSet().length != list.length) {
        throw ArgumentError('音色需有名称，且不能重复');
      }
    }
    if (codePath.isNotEmpty && successCodes.isEmpty ||
        completionCode != null &&
            (codePath.isEmpty || !successCodes.contains(completionCode))) {
      throw ArgumentError('请配置有效的成功状态与完成状态');
    }
  }

  Map<String, Object?> toJson() => {
    'baseUrl': baseUrl,
    'path': path,
    'authHeader': authHeader,
    'authPrefix': authPrefix,
    'modelPath': modelPath,
    'textPath': textPath,
    'voicePath': voicePath,
    'audioPath': audioPath,
    'fileExtension': fileExtension,
    'modelHeader': modelHeader,
    'codePath': codePath,
    'responseFormat': responseFormat.name,
    'audioEncoding': audioEncoding.name,
    'body': body,
    'headers': headers,
    'successCodes': successCodes,
    'completionCode': completionCode,
    'maxCharacters': maxCharacters,
    'voices': [for (final voice in voices) voice.toJson()],
    'voiceCatalog': [for (final voice in voiceCatalog) voice.toJson()],
    'autoSyncVoices': autoSyncVoices,
    'voiceList': voiceList?.toJson(),
  };

  factory SpeechApiConfig.fromJson(Map<String, dynamic> json) =>
      SpeechApiConfig(
        baseUrl: json['baseUrl'] as String,
        path: json['path'] as String,
        authHeader: json['authHeader'] as String,
        authPrefix: json['authPrefix'] as String,
        modelPath: json['modelPath'] as String,
        textPath: json['textPath'] as String,
        voicePath: json['voicePath'] as String,
        audioPath: json['audioPath'] as String,
        fileExtension: json['fileExtension'] as String,
        modelHeader: json['modelHeader'] as String,
        codePath: json['codePath'] as String,
        responseFormat: SpeechResponseFormat.values.byName(
          json['responseFormat'] as String,
        ),
        audioEncoding: SpeechAudioEncoding.values.byName(
          json['audioEncoding'] as String,
        ),
        body: Map<String, Object?>.from(json['body'] as Map),
        headers: Map<String, String>.from(json['headers'] as Map),
        successCodes: List<Object?>.from(json['successCodes'] as List),
        completionCode: json['completionCode'],
        maxCharacters: json['maxCharacters'] as int,
        voices: [
          for (final row in json['voices'] as List)
            SpeechVoice.fromJson(row as Map),
        ],
        voiceCatalog: [
          for (final row in json['voiceCatalog'] as List)
            SpeechVoice.fromJson(row as Map),
        ],
        autoSyncVoices: json['autoSyncVoices'] as bool,
        voiceList: json['voiceList'] == null
            ? null
            : SpeechVoiceListConfig.fromJson(
                Map<String, dynamic>.from(json['voiceList'] as Map),
              ),
      );
}
