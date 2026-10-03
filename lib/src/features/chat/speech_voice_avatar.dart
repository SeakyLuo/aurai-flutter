import 'package:flutter/material.dart';

class SpeechVoiceAvatar extends StatelessWidget {
  const SpeechVoiceAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 48,
  });
  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 14 / 48),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(size * 14 / 48),
      ),
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: size * 21 / 48,
          fontWeight: FontWeight.w500,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
