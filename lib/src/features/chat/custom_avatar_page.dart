import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import 'avatar_color_library.dart';
import 'avatar_symbol.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';

class CustomAvatarPage extends StatefulWidget {
  const CustomAvatarPage({
    super.key,
    required this.initial,
    required this.name,
  });
  final AvatarStyle initial;
  final String name;
  @override
  State<CustomAvatarPage> createState() => _CustomAvatarPageState();
}

class _CustomAvatarPageState extends State<CustomAvatarPage> {
  late String _icon = widget.initial.icon;
  late String _color = widget.initial.color;
  AvatarStyle get _style => AvatarStyle(icon: _icon, color: _color);

  @override
  Widget build(BuildContext context) => Scaffold(
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
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: ProfileAvatar(style: _style, name: widget.name, size: 104),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                const Text('图案', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                _grid([
                  for (final entry in avatarSymbols.entries)
                    _choice(
                      entry.value,
                      _icon == entry.key,
                      () => setState(() => _icon = entry.key),
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
