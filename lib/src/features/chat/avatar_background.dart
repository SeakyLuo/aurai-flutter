import 'dart:math' as math;
import 'package:flutter/material.dart';

const avatarColors = <String, (String, Color)>{
  'slate': ('灰绿', Color(0xff7c9291)),
  'violet': ('紫色', Color(0xff9279c3)),
  'blue': ('蓝色', Color(0xff618dc5)),
  'green': ('绿色', Color(0xff599b80)),
  'rose': ('玫瑰', Color(0xffbd7d99)),
  'orange': ('橙色', Color(0xffc18d59)),
  'red': ('珊瑚', Color(0xffbf7471)),
  'ink': ('深灰', Color(0xff636978)),
};

const avatarGradients = <String, (String, Color, Color)>{
  'aurora': ('极光', Color(0xff53b9a5), Color(0xff6367ba)),
  'iris': ('鸢尾', Color(0xffa78cda), Color(0xff5968b5)),
  'ocean': ('海风', Color(0xff66c5ce), Color(0xff4873b5)),
  'forest': ('森林', Color(0xff9bbd7e), Color(0xff377c76)),
  'peach': ('蜜桃', Color(0xffeab18c), Color(0xffcc728d)),
  'sunset': ('落日', Color(0xffe2a658), Color(0xffc76677)),
  'berry': ('莓果', Color(0xffd886b3), Color(0xff895cad)),
  'dusk': ('暮色', Color(0xffae9cc6), Color(0xff596c96)),
  'lagoon': ('青湾', Color(0xff78c8ad), Color(0xff347f95)),
  'sand': ('暖砂', Color(0xffcdb087), Color(0xff9e7879)),
  'flame': ('丹霞', Color(0xffed9678), Color(0xffba596b)),
  'night': ('夜空', Color(0xff7383a9), Color(0xff404767)),
};

class AvatarBackground {
  const AvatarBackground(this.start, this.end, [this.angle = .125]);
  final Color start;
  final Color end;
  final double angle;

  factory AvatarBackground.decode(String value) {
    if (value.startsWith('custom:')) {
      final parts = value.split(':');
      return AvatarBackground(
        Color(int.parse(parts[1], radix: 16)),
        Color(int.parse(parts[2], radix: 16)),
        double.parse(parts[3]),
      );
    }
    if (value.startsWith('gradient:')) {
      final preset = avatarGradients[value.substring(9)]!;
      return AvatarBackground(preset.$2, preset.$3);
    }
    final color = avatarColors[value]!.$2;
    return AvatarBackground(color, color);
  }

  String get encoded =>
      'custom:${start.toARGB32().toRadixString(16)}:'
      '${end.toARGB32().toRadixString(16)}:$angle';
  LinearGradient get gradient {
    final direction = Alignment(
      math.cos(angle * math.pi * 2),
      math.sin(angle * math.pi * 2),
    );
    return LinearGradient(
      begin: -direction,
      end: direction,
      colors: [start, end],
    );
  }

  Color get foreground =>
      (start.computeLuminance() + end.computeLuminance()) / 2 > .5
      ? const Color(0xff273449)
      : Colors.white;
}
