import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_purpose_catalog.dart';
import '../../providers/speech_voice_catalog.dart';
import 'provider_settings_draft.dart';
import 'speech_preview_settings_sheet.dart';
import '../../domain/speech_preview_mode.dart';

/// Shared audition state for managing and choosing supplier voices.
class SpeechVoicePreviewController extends ChangeNotifier {
  SpeechVoicePreviewController({required this.config, required this.voices});
  final ModelConfig Function() config;
  final List<SpeechVoice> Function() voices;
  String text = '你好，这是我的声音。';
  bool get hasProviderPreview => voices().any(
    (voice) =>
        voice.previewUrl?.isNotEmpty == true ||
        voice.previewText?.isNotEmpty == true,
  );
  SpeechPreviewMode? _mode;
  SpeechPreviewMode get mode {
    if (_mode != null && _mode != SpeechPreviewMode.customText) return _mode!;
    if (voices().any((voice) => voice.previewUrl?.isNotEmpty == true)) {
      return SpeechPreviewMode.providerAudio;
    }
    if (voices().any((voice) => voice.previewText?.isNotEmpty == true)) {
      return SpeechPreviewMode.providerText;
    }
    return SpeechPreviewMode.customText;
  }

  String? voice;
  late String model = models.any((entry) => entry.id == config().model)
      ? config().model
      : models.firstOrNull?.id ?? '';

  List<({String id, String name})> get models {
    final account = config();
    return {
          ...account.modelCatalog.map((entry) => entry.id),
          ...account.savedModels,
          ...?account.details?.modelPurposes.keys,
        }
        .where(
          (id) =>
              modelPurposesFor(
                account,
                id,
              ).contains(ModelPurpose.speechSynthesis) &&
              (account.autoSyncModels || account.savedModels.contains(id)),
        )
        .map((id) => (id: id, name: account.displayModel(id)))
        .toList();
  }

  void stop() {
    voice = null;
    notifyListeners();
  }

  Future<void> settings(BuildContext context) async {
    final available = models;
    final hasDefaultText = voices().any(
      (voice) => voice.previewText?.isNotEmpty == true,
    );
    final hasDefaultAudio = voices().any(
      (voice) => voice.previewUrl?.isNotEmpty == true,
    );
    if (available.isEmpty && !hasDefaultAudio) {
      ScaffoldMessenger.of(context).showToast(
        const SnackBar(content: Text('请先在模型管理中添加语音合成模型')),
        kind: ToastKind.warning,
      );
      return;
    }
    stop();
    final result = await showSpeechPreviewSettingsSheet(
      context,
      text: text,
      model: model,
      models: available,
      mode: mode,
      hasDefaultText: hasDefaultText,
      hasDefaultAudio: hasDefaultAudio,
    );
    if (!context.mounted || result == null) return;
    model = result.model;
    text = result.text;
    _mode = result.mode;
    notifyListeners();
  }

  Future<void> activate(BuildContext context, String id) async {
    if (mode != SpeechPreviewMode.providerAudio && model.isEmpty)
      await settings(context);
    if (context.mounted &&
        (mode == SpeechPreviewMode.providerAudio || model.isNotEmpty)) {
      voice = id;
      notifyListeners();
    }
  }

  ModelConfig get account {
    final current = config();
    final draft = ProviderSettingsDraft(current.copyWith(model: model));
    draft.updateDetails({
      'speechApi': {
        ...current.speechApi!.toJson(),
        'voices': [for (final entry in voices()) entry.toJson()],
      },
    });
    return draft.config;
  }
}
