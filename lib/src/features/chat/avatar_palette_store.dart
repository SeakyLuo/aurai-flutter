import 'package:shared_preferences/shared_preferences.dart';
import 'avatar_background.dart';

class AvatarPaletteStore {
  final _preferences = SharedPreferencesAsync();
  static String key(bool gradient) =>
      gradient ? 'avatar.palette.gradients' : 'avatar.palette.solids';
  static List<String> defaults(bool gradient) => gradient
      ? [for (final key in avatarGradients.keys) 'gradient:$key']
      : avatarColors.keys.toList();

  Future<({List<String> solids, List<String> gradients})> load() async {
    final lists = await Future.wait([
      _preferences.getStringList(key(false)),
      _preferences.getStringList(key(true)),
    ]);
    return (
      solids: lists[0] ?? defaults(false),
      gradients: lists[1] ?? defaults(true),
    );
  }

  Future<void> save(bool gradient, List<String> colors) =>
      _preferences.setStringList(key(gradient), colors);
}
