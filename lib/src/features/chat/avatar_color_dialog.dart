import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import 'avatar_background.dart';
import 'avatar_color_palette.dart';
import 'dialog_action_button.dart';
import 'profile_avatar.dart';

class AvatarColorDialog extends StatefulWidget {
  const AvatarColorDialog({
    super.key,
    required this.gradient,
    required this.initial,
    required this.icon,
    required this.name,
  });
  final bool gradient;
  final AvatarBackground initial;
  final String icon;
  final String name;
  @override
  State<AvatarColorDialog> createState() => _AvatarColorDialogState();
}

class _AvatarColorDialogState extends State<AvatarColorDialog> {
  late final _colors = [
    HSVColor.fromColor(widget.initial.start),
    HSVColor.fromColor(widget.initial.end),
  ];
  late double _angle = widget.initial.angle;
  int _stop = 0;
  AvatarBackground get _background => AvatarBackground(
    _colors[0].toColor(),
    widget.gradient ? _colors[1].toColor() : _colors[0].toColor(),
    widget.gradient ? _angle : 0,
  );
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gradient ? '添加渐变' : '添加纯色',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      ProfileAvatar(
                        style: AvatarStyle(
                          icon: widget.icon,
                          color: _background.encoded,
                        ),
                        name: widget.name,
                        size: 72,
                      ),
                      const SizedBox(height: 20),
                      if (widget.gradient) ...[
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _stop = i),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      side: BorderSide(
                                        color: _stop == i
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                        width: _stop == i ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _colors[i].toColor(),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(i == 0 ? '起始色' : '结束色'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      AvatarColorPalette(
                        value: _colors[_stop],
                        onChanged: (color) =>
                            setState(() => _colors[_stop] = color),
                      ),
                      if (widget.gradient) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final direction in const [
                              ('左右', 0.0),
                              ('上下', .25),
                              ('斜向', .125),
                              ('反斜向', .375),
                            ])
                              Expanded(
                                child: Semantics(
                                  selected: _angle == direction.$2,
                                  button: true,
                                  label: direction.$1,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        setState(() => _angle = direction.$2),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                width: 2,
                                                color: _angle == direction.$2
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: AvatarBackground(
                                                  _colors[0].toColor(),
                                                  _colors[1].toColor(),
                                                  direction.$2,
                                                ).gradient,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            direction.$1,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DialogActionButton(
                    text: '取消',
                    role: DialogActionRole.secondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DialogActionButton(
                    text: '保存',
                    onPressed: () =>
                        Navigator.pop(context, _background.encoded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
