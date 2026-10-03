import 'dart:math' as math;
import 'package:flutter/material.dart';

const softAvatarColors = <String, (String, Color)>{
  'soft_rose': ('藕粉', Color(0xfff2cdd0)),
  'soft_pink': ('浅粉', Color(0xfff7d8e7)),
  'soft_peach': ('蜜桃', Color(0xffffddbd)),
  'soft_sand': ('燕麦', Color(0xffeadcc4)),
  'soft_lemon': ('奶黄', Color(0xfff6eab0)),
  'soft_sage': ('鼠尾草', Color(0xffdeebc4)),
  'soft_mint': ('薄荷', Color(0xffc5e8cc)),
  'soft_aqua': ('浅青', Color(0xffc1e9e6)),
  'soft_blue': ('浅蓝', Color(0xffcddffc)),
  'soft_lavender': ('浅紫', Color(0xffded5f5)),
  'soft_lilac': ('丁香', Color(0xffecd5ef)),
  'soft_slate': ('雾灰', Color(0xffdce0e5)),
};

const avatarColors = <String, (String, Color)>{
  ...softAvatarColors,
  'red': ('红色', Color(0xffc85f63)),
  'rose': ('玫瑰', Color(0xffc66d9b)),
  'orange': ('橙色', Color(0xffd18442)),
  'yellow': ('黄色', Color(0xffbea02d)),
  'cream': ('奶油', Color(0xffdec690)),
  'green': ('绿色', Color(0xff3e9a69)),
  'cyan': ('青色', Color(0xff279ca5)),
  'blue': ('蓝色', Color(0xff468dcc)),
  'indigo': ('靛蓝', Color(0xff6171bd)),
  'violet': ('紫色', Color(0xff9067c6)),
  'slate': ('灰绿', Color(0xff718d89)),
  'ink': ('黑色', Color(0xff555d6d)),
};

const avatarGradients = <String, (String, Color, Color)>{
  'flame': ('丹霞', Color(0xfff06b5f), Color(0xffbd3f62)),
  'peach': ('蜜桃', Color(0xfff2a15f), Color(0xffdf6f8c)),
  'sunset': ('落日', Color(0xfff0bd45), Color(0xffdd684f)),
  'sand': ('暖砂', Color(0xffdfc477), Color(0xff9c746d)),
  'forest': ('森林', Color(0xff9bcb69), Color(0xff2f8068)),
  'aurora': ('极光', Color(0xff42b998), Color(0xff6265c5)),
  'lagoon': ('青湾', Color(0xff68c9a3), Color(0xff208b9e)),
  'ocean': ('海风', Color(0xff4fc4d4), Color(0xff416fca)),
  'dusk': ('暮色', Color(0xff809dcc), Color(0xff51578e)),
  'iris': ('鸢尾', Color(0xffb07adb), Color(0xff5664c6)),
  'berry': ('莓果', Color(0xffdd6fac), Color(0xff8350b0)),
  'night': ('夜空', Color(0xff66799f), Color(0xff2d344f)),
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
