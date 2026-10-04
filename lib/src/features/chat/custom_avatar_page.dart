import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/avatar_style.dart';
import '../../storage/avatar_symbol_recents.dart';
import 'avatar_color_library.dart';
import 'avatar_selection_mark.dart';
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
  List<String> _recentSymbols = [];
  AvatarStyle get _style => AvatarStyle(icon: _icon, color: _color);

  @override
  void initState() {
    super.initState();
    _loadRecentSymbols();
  }

  Future<void> _loadRecentSymbols() async {
    final values = await AvatarSymbolRecents.load(widget.database);
    if (mounted) setState(() => _recentSymbols = values);
  }

  List<MapEntry<String, String>> get _visibleSymbols {
    const keys = [
      'app_logo_white',
      'initial',
      'portrait:dark_hair_boy',
      'portrait:brown_hair_girl',
      'portrait:little_robot',
      'emoji:😀',
      'emoji:😎',
      'emoji:🥰',
      'emoji:🐱',
      'emoji:🐶',
      'person',
      'spark',
      'puzzle',
      'memory',
      'smile',
    ];
    return [
      for (final key in {..._recentSymbols, ...keys}.take(15))
        MapEntry(key, key.startsWith('emoji:') ? 'Emoji' : avatarSymbols[key]!),
    ];
  }

  Future<void> _selectSymbol(String value) async {
    setState(() => _icon = value);
    final values = await AvatarSymbolRecents.record(widget.database, value);
    if (mounted) setState(() => _recentSymbols = values);
  }

  Future<void> _showAllSymbols() async {
    final icon = await showAvatarSymbolPicker(
      context,
      selected: _icon,
      color: _color,
      name: widget.name,
    );
    if (icon != null && mounted) await _selectSymbol(icon);
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
                        entry.key,
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

  Widget _grid(List<Widget> children) => GridView.count(
    crossAxisCount: 5,
    padding: EdgeInsets.zero,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    children: children,
  );

  Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap,
    String value,
  ) => Semantics(
    label: label,
    selected: selected,
    button: true,
    child: Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: AvatarSelectionMark(
                  selected: selected,
                  child: ProfileAvatar(
                    style: AvatarStyle(icon: value, color: _color),
                    name: widget.name,
                    size: constraints.biggest.shortestSide - 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
