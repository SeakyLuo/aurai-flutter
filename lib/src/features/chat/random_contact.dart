import 'offline_contact_candidates.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import '../../domain/response_preferences.dart';
import 'avatar_background.dart';
import 'avatar_symbol.dart';
import 'avatar_palette_store.dart';

class RandomContact {
  const RandomContact(
    this.name,
    this.description,
    this.role,
    this.avatar,
    this.responses,
  );
  final String name, description, role;
  final AvatarStyle avatar;
  final ResponsePreferences responses;

  static final _random = Random();
  static final _candidateBag = <int>[];
  static Future<String> savedAvatarColor() async {
    final palette = await AvatarPaletteStore().load();
    final colors = [...palette.solids, ...palette.gradients];
    if (colors.isEmpty) throw StateError('头像色库为空，请先添加或重置配色');
    return colors[_random.nextInt(colors.length)];
  }

  static RandomContact roll({String? avatarColor}) {
    if (_candidateBag.isEmpty) {
      _candidateBag.addAll(
        List.generate(offlineContactCandidates.length, (i) => i)
          ..shuffle(_random),
      );
    }
    final candidate = offlineContactCandidates[_candidateBag.removeLast()];
    final colors = [
      ...avatarColors.keys,
      for (final key in avatarGradients.keys) 'gradient:$key',
    ];
    final symbols = avatarSymbols.keys
        .where((key) => !key.startsWith('app_logo'))
        .toList();
    return RandomContact(
      candidate.name,
      candidate.description,
      candidate.role,
      AvatarStyle(
        icon: symbols[_random.nextInt(symbols.length)],
        color: avatarColor ?? colors[_random.nextInt(colors.length)],
      ),
      ResponsePreferences(
        style:
            ResponseStyle.values[_random.nextInt(ResponseStyle.values.length)],
        traits: {
          for (final trait in ResponseTrait.values)
            trait: TraitLevel.values[_random.nextInt(TraitLevel.values.length)],
        },
      ),
    );
  }
}

class RollContactIcon extends StatelessWidget {
  const RollContactIcon({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _DicePainter(
      Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : const Color(0xff222222),
    ),
  );
}

class _DicePainter extends CustomPainter {
  const _DicePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, 18, 18),
        const Radius.circular(4),
      ),
      pen,
    );
    for (final point in [
      const Offset(8, 8),
      const Offset(12, 12),
      const Offset(16, 16),
    ]) {
      canvas.drawCircle(point, 1.25, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_DicePainter oldDelegate) => color != oldDelegate.color;
}
