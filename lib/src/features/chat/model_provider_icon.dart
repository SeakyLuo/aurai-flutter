import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';

class ModelProviderIcon extends StatelessWidget {
  const ModelProviderIcon({super.key, required this.service});
  final ModelService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final asset = switch (service) {
      ModelService.openAi => 'openai',
      ModelService.deepSeek => 'deepseek-color',
      ModelService.qwen => 'qwen-color',
      ModelService.kimi => 'kimi-color',
      ModelService.glm => 'zhipu-color',
      ModelService.openRouter => 'openrouter-grape',
    };
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: service == ModelService.kimi
            ? const Color(0xFF16191E)
            : dark
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Image.asset(
        'assets/providers/$asset.png',
        fit: BoxFit.contain,
        cacheWidth: 112,
        excludeFromSemantics: true,
        color: service == ModelService.openAi
            ? theme.colorScheme.onSurface
            : null,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
