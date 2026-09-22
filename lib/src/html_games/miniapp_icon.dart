import 'dart:io';
import 'package:flutter/material.dart';
import '../features/chat/settings_icon.dart';

class MiniappIcon extends StatelessWidget {
  const MiniappIcon({
    super.key,
    required this.path,
    this.asset,
    this.size = 24,
  });
  final String? path, asset;
  final double size;

  Widget _defaultIcon() => SizedBox.square(
    dimension: size,
    child: const FittedBox(
      child: SettingsIcon(type: SettingsIconType.miniapps),
    ),
  );

  @override
  Widget build(BuildContext context) => path == null
      ? asset == null
            ? _defaultIcon()
            : ClipRRect(
                borderRadius: BorderRadius.circular(size * .22),
                child: Image.asset(
                  asset!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              )
      : ClipRRect(
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.file(
            File(path!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            errorBuilder: (_, _, _) => _defaultIcon(),
          ),
        );
}
