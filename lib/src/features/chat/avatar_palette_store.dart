import 'package:shared_preferences/shared_preferences.dart';
import 'avatar_background.dart';

enum AvatarPaletteKind {
  solid,
  soft,
  gradient;

  String get label => switch (this) {
    solid => '纯色',
    soft => '柔和',
    gradient => '渐变',
  };
}

class AvatarPaletteStore {
  final _preferences = SharedPreferencesAsync();
  static String key(AvatarPaletteKind kind) => switch (kind) {
    AvatarPaletteKind.solid => 'avatar.palette.solids',
    AvatarPaletteKind.soft => 'avatar.palette.soft',
    AvatarPaletteKind.gradient => 'avatar.palette.gradients',
  };
  static List<String> defaults(AvatarPaletteKind kind) => switch (kind) {
    AvatarPaletteKind.gradient => [
      for (final key in avatarGradients.keys) 'gradient:$key',
    ],
    AvatarPaletteKind.soft => softAvatarColors.keys.toList(),
    AvatarPaletteKind.solid =>
      avatarColors.keys
          .where((key) => !softAvatarColors.containsKey(key))
          .toList(),
  };
  Future<({List<String> solids, List<String> softs, List<String> gradients})>
  load() async {
    final lists = await Future.wait([
      for (final kind in AvatarPaletteKind.values)
        _preferences.getStringList(key(kind)),
    ]);
    final softs = lists[1] ?? defaults(AvatarPaletteKind.soft);
    final selectedSofts = softs.toSet();
    return (
      solids: lists[0] ?? defaults(AvatarPaletteKind.solid),
      softs: [
        for (final color in softAvatarColors.keys)
          if (selectedSofts.contains(color)) color,
        for (final color in softs)
          if (!softAvatarColors.containsKey(color)) color,
      ],
      gradients: lists[2] ?? defaults(AvatarPaletteKind.gradient),
    );
  }

  Future<void> save(AvatarPaletteKind kind, List<String> colors) =>
      _preferences.setStringList(key(kind), colors);
}
