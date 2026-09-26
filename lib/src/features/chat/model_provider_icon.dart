import 'dart:io';

import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';

class ModelProviderIcon extends StatelessWidget {
  const ModelProviderIcon({super.key, required this.config});
  final ModelConfig config;

  @override
  Widget build(BuildContext context) {
    final selected = config.icon;
    if (selected != null && selected.startsWith('file:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(selected.substring(5)),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      );
    }
    return ProviderIconPreview(
      icon: selected == null
          ? config.service.defaultIcon
          : ProviderIcon.values.byName(selected),
      label: config.service.defaultIconText ?? config.displayName,
    );
  }
}

class ProviderIconPreview extends StatelessWidget {
  const ProviderIconPreview({
    super.key,
    required this.icon,
    required this.label,
  });
  final ProviderIcon icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final asset = icon.asset;
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: icon == ProviderIcon.kimi
            ? const Color(0xFF16191E)
            : dark
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: asset.isEmpty
          ? Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  label.isEmpty
                      ? 'A'
                      : label.characters.length <= 3
                      ? label.toUpperCase()
                      : label.characters.first.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          : Image.asset(
              'assets/providers/$asset.png',
              fit: BoxFit.contain,
              cacheWidth: 112,
              excludeFromSemantics: true,
              color: icon.monochrome ? theme.colorScheme.onSurface : null,
              colorBlendMode: BlendMode.srcIn,
            ),
    );
  }
}
