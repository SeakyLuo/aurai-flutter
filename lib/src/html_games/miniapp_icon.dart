import 'dart:io';
import 'package:flutter/material.dart';
import 'miniapp_symbol.dart';

class MiniappIcon extends StatelessWidget {
  const MiniappIcon({
    super.key,
    required this.path,
    this.asset,
    this.size = 24,
  });
  final String? path, asset;
  final double size;

  Widget _defaultIcon(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(size * .22),
    ),
    alignment: Alignment.center,
    child: MiniappSymbol(size: size * .52),
  );

  @override
  Widget build(BuildContext context) => path == null
      ? asset == null
            ? _defaultIcon(context)
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
            errorBuilder: (_, _, _) => _defaultIcon(context),
          ),
        );
}
