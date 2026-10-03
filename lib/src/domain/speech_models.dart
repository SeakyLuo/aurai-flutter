import 'speech_api_config.dart';
import 'speech_voice.dart';
import 'speech_voice_details.dart';
import 'speech_voice_list_config.dart';
import 'profile_gender.dart';

/// Provider presets are data; the speech client consumes only configuration.
abstract final class SpeechModels {
  // Gender metadata for the built-in provider voices; custom voices stay unknown.
  // https://www.alibabacloud.com/help/en/model-studio/qwen-tts-voice-list
  static const voiceGenders = <String, ProfileGender>{
    'Cherry': ProfileGender.female,
    'Serena': ProfileGender.female,
    'Ethan': ProfileGender.male,
    'Chelsie': ProfileGender.female,
    'Dylan': ProfileGender.male,
    'Jada': ProfileGender.female,
    'Sunny': ProfileGender.female,
    'zh_female_vv_uranus_bigtts': ProfileGender.female,
    'zh_female_xiaohe_uranus_bigtts': ProfileGender.female,
    'zh_male_m191_uranus_bigtts': ProfileGender.male,
    'zh_male_taocheng_uranus_bigtts': ProfileGender.male,
    'zh_female_xiaoxue_uranus_bigtts': ProfileGender.female,
  };
  static const qwen = [
    (id: 'qwen3-tts-flash', name: '千问3 TTS Flash'),
    (id: 'qwen3-tts-instruct-flash', name: '千问3 TTS Instruct Flash'),
  ];
  static const doubao = [(id: 'seed-tts-2.0', name: '豆包语音合成 2.0')];
  static const qwenVoices = [
    SpeechVoice(
      id: 'Cherry',
      name: '芊悦',
      details: SpeechVoiceDetails(
        ['普通话', '多语言', '青年'],
        '阳光积极，亲切自然。',
        gender: 'female',
      ),
    ),
    SpeechVoice(
      id: 'Serena',
      name: '苏瑶',
      details: SpeechVoiceDetails(
        ['普通话', '多语言', '青年'],
        '温柔柔和，轻声陪伴。',
        gender: 'female',
      ),
    ),
    SpeechVoice(
      id: 'Ethan',
      name: '晨煦',
      details: SpeechVoiceDetails(
        ['普通话 · 北方口音', '多语言'],
        '阳光温暖，富有活力。',
        gender: 'male',
      ),
    ),
    SpeechVoice(
      id: 'Chelsie',
      name: '千雪',
      details: SpeechVoiceDetails(
        ['普通话', '多语言'],
        '柔软甜美，带有俏皮的气声。',
        gender: 'female',
      ),
    ),
    SpeechVoice(
      id: 'Dylan',
      name: '晓东 · 北京话',
      details: SpeechVoiceDetails(
        ['北京话', '多语言', '青年'],
        '北京胡同里的少年，自然地道。',
        gender: 'male',
      ),
    ),
    SpeechVoice(
      id: 'Jada',
      name: '阿珍 · 上海话',
      details: SpeechVoiceDetails(
        ['上海话', '多语言'],
        '语速明快，充满活力的上海阿姨。',
        gender: 'female',
      ),
    ),
    SpeechVoice(
      id: 'Sunny',
      name: '晴儿 · 四川话',
      details: SpeechVoiceDetails(
        ['四川话', '多语言'],
        '甜美亲切的四川女孩。',
        gender: 'female',
      ),
    ),
  ];
  static const qwenApi = SpeechApiConfig(
    baseUrl: 'https://dashscope.aliyuncs.com/api/v1',
    path: 'services/aigc/multimodal-generation/generation',
    authHeader: 'Authorization',
    authPrefix: 'Bearer ',
    modelPath: 'model',
    textPath: 'input.text',
    voicePath: 'input.voice',
    audioPath: 'output.audio.url',
    audioEncoding: SpeechAudioEncoding.url,
    fileExtension: 'wav',
    voices: qwenVoices,
    voiceCatalog: qwenVoices,
    body: {
      'input': {'language_type': 'Auto'},
    },
  );
  static const doubaoApi = SpeechApiConfig(
    baseUrl: 'https://openspeech.bytedance.com/api/v3',
    path: 'tts/unidirectional',
    authHeader: 'X-Api-Key',
    modelPath: '',
    modelHeader: 'X-Api-Resource-Id',
    textPath: 'req_params.text',
    voicePath: 'req_params.speaker',
    audioPath: 'data',
    audioEncoding: SpeechAudioEncoding.base64,
    responseFormat: SpeechResponseFormat.jsonLines,
    fileExtension: 'mp3',
    autoSyncVoices: true,
    voiceList: SpeechVoiceListConfig(
      url:
          'https://open.volcengineapi.com/?Action=ListSpeakers&Version=2025-05-20',
      method: 'POST',
      authentication: VoiceListAuthentication.hmacSha256,
      region: 'cn-beijing',
      service: 'speech_saas_prod',
      listPath: 'Result.Speakers',
      idPath: 'VoiceType',
      namePath: 'Name',
      avatarPath: 'Avatar',
      previewTextPath: 'Languages.0.Text',
      previewUrlPath: 'TrialURL',
      genderPath: 'Gender',
      genderValues: {'男': 'male', '女': 'female'},
      descriptionPath: 'Description',
      tagPaths: [
        'Languages.*.Language',
        'Age',
        'NormalLabels',
        'SpecialLabels',
        'Categories.*.Categories',
        'Emotions.*.Label',
      ],
      pagePath: 'Page',
      totalPath: 'Result.Total',
      body: {
        'ResourceIDs': ['seed-tts-2.0'],
        'Limit': 100,
      },
    ),
    codePath: 'code',
    successCodes: [0, 20000000],
    completionCode: 20000000,
    body: {
      'req_params': {
        'audio_params': {'format': 'mp3', 'sample_rate': 24000},
      },
    },
  );
}
