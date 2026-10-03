enum SpeechPreviewMode {
  customText('自定义文案'),
  providerText('供应商默认文案'),
  providerAudio('供应商默认音频');

  const SpeechPreviewMode(this.label);
  final String label;
}
