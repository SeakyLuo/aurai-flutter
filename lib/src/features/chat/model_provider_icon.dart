import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';

class ModelProviderIcon extends StatelessWidget {
  const ModelProviderIcon({super.key, required this.service});
  final ModelService service;

  @override
  Widget build(BuildContext context) {
    final asset = switch (service) {
      ModelService.openAi => 'openai',
      ModelService.deepSeek => 'deepseek-color',
      ModelService.qwen => 'qwen-color',
      ModelService.kimi => 'kimi-color',
      ModelService.glm => 'zhipu-color',
    };
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: service == ModelService.kimi
            ? const Color(0xFF16191E)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Image.asset(
        'assets/providers/$asset.png',
        excludeFromSemantics: true,
      ),
    );
  }
}
