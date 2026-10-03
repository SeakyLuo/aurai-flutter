import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/avatar_style.dart';
import '../../storage/avatar_symbol_recents.dart';
import 'avatar_color_library.dart';
import 'avatar_symbol.dart';
import 'avatar_symbol_picker.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';

class CustomAvatarPage extends StatefulWidget {
  const CustomAvatarPage({
    super.key,
    required this.initial,
    required this.name,
    required this.database,
  });
  final AvatarStyle initial;
  final String name;
  final Database database;
  @override
  State<CustomAvatarPage> createState() => _CustomAvatarPageState();
}

class _CustomAvatarPageState extends State<CustomAvatarPage> {
  late String _icon = widget.initial.icon;
  late String _color = widget.initial.color;
  List<String> _recentSymbols = const [];
  AvatarStyle get _style => AvatarStyle(icon: _icon, color: _color);

  @override
  void initState() {
    super.initState();
    AvatarSymbolRecents.load(widget.database).then((values) {
      if (mounted) setState(() => _recentSymbols = values);
    });
  }

  List<MapEntry<String, String>> get _visibleSymbols {
    const fixedKeys = ['app_logo_white', 'initial'];
    final icons = {...avatarSymbols.keys}
        .where(
          (key) => !fixedKeys.contains(key) && !key.startsWith('portrait:'),
        )
        .toList();
    final emojis = {
      'emoji:😀',
      'emoji:😎',
      'emoji:🥰',
      'emoji:🐱',
      'emoji:🐶',
      'emoji:🌸',
      'emoji:🌈',
      'emoji:☀️',
      'emoji:🍀',
    }.toList();
    return [
      for (final key in fixedKeys) MapEntry(key, avatarSymbols[key]!),
      for (final key in <String>{
        ..._recentSymbols.where(
          (key) =>
              !fixedKeys.contains(key) &&
              (avatarSymbols.containsKey(key) || key.startsWith('emoji:')),
        ),
        'portrait:dark_hair_boy',
        'portrait:brown_hair_girl',
        'portrait:little_robot',
        ...emojis.take(7),
        ...icons,
      })
        MapEntry(key, avatarSymbols[key] ?? 'Emoji'),
    ].take(24).toList();
  }

  Future<void> _selectSymbol(String value, {bool reorder = false}) async {
    setState(() => _icon = value);
    const fixed = ['app_logo_white', 'initial'];
    final recent = fixed.contains(value)
        ? _recentSymbols
        : await AvatarSymbolRecents.record(widget.database, value);
    if (mounted && reorder) {
      setState(() => _recentSymbols = recent);
    }
  }

  Future<void> _showAllSymbols() async {
    final icon = await showAvatarSymbolPicker(
      context,
      selected: _icon,
      color: _color,
      name: widget.name,
    );
    if (icon != null && mounted) await _selectSymbol(icon, reorder: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '自定义头像',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '使用头像',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, _style),
        ),
      ],
    ),
    body: SettingsPageBody(
      avoidHeader: true,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ProfileAvatar(
                  style: _style,
                  name: widget.name,
                  size: 104,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('图案', style: TextStyle(fontSize: 15)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(left: 16),
                          alignment: Alignment.centerRight,
                        ),
                        onPressed: _showAllSymbols,
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _grid([
                    for (final entry in _visibleSymbols)
                      _choice(
                        entry.value,
                        _icon == entry.key,
                        () => _selectSymbol(entry.key),
                        ProfileAvatar(
                          style: AvatarStyle(icon: entry.key, color: _color),
                          name: widget.name,
                          size: 40,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 24),
                  AvatarColorLibrary(
                    selected: _color,
                    icon: _icon,
                    name: widget.name,
                    onSelected: (color) => setState(() => _color = color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 52).floor().clamp(1, 6);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: children,
      );
    },
  );

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap,
    Widget child,
  ) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
