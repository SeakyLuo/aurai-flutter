import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_palette_store.dart';
import 'avatar_background.dart';
import 'avatar_color_dialog.dart';
import 'dialog_action_button.dart';
import 'glass_surface.dart';
import 'settings_icon.dart';

class AvatarColorLibrary extends StatefulWidget {
  const AvatarColorLibrary({
    super.key,
    required this.selected,
    required this.icon,
    required this.name,
    required this.onSelected,
  });
  final String selected;
  final String icon;
  final String name;
  final ValueChanged<String> onSelected;
  @override
  State<AvatarColorLibrary> createState() => _AvatarColorLibraryState();
}

class _AvatarColorLibraryState extends State<AvatarColorLibrary> {
  final _palette = AvatarPaletteStore();
  List<String>? _solid;
  List<String>? _gradients;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await _palette.load();
      if (mounted)
        setState(() {
          _solid = lists.solids;
          _gradients = lists.gradients;
        });
    } catch (_) {
      if (mounted) {
        _notice('配色读取失败');
        Navigator.pop(context);
      }
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<bool> _save(bool gradient, List<String> values) async {
    setState(() => _busy = true);
    try {
      await _palette.save(gradient, values);
      if (!mounted) return false;
      setState(() {
        if (gradient) {
          _gradients = values;
        } else {
          _solid = values;
        }
      });
      return true;
    } catch (_) {
      if (mounted) _notice('配色保存失败，请重试');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(bool gradient) async {
    final current = AvatarBackground.decode(widget.selected);
    final initial = gradient && current.start == current.end
        ? AvatarBackground.decode('gradient:iris')
        : current;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AvatarColorDialog(
        gradient: gradient,
        initial: initial,
        icon: widget.icon,
        name: widget.name,
      ),
    );
    if (result == null || !mounted) return;
    final values = gradient ? _gradients! : _solid!;
    final match = values.where((value) {
      final saved = AvatarBackground.decode(value);
      final added = AvatarBackground.decode(result);
      return saved.start == added.start &&
          saved.end == added.end &&
          (!gradient || saved.angle == added.angle);
    }).firstOrNull;
    if (match != null) {
      widget.onSelected(match);
      return;
    }
    if (await _save(gradient, [...values, result]) && mounted)
      widget.onSelected(result);
  }

  Future<void> _remove(bool gradient, String? value) async {
    final reset = value == null;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: GlassSurface(
            radius: 28,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reset ? '重置${gradient ? '渐变' : '纯色'}配色？' : '删除这个配色？',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reset ? '恢复本组默认配色并移除本组自定义配色，已使用的头像不变。' : '仅从色库移除，已使用的头像不变。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: DialogActionButton(
                          text: '取消',
                          role: DialogActionRole.secondary,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DialogActionButton(
                          text: reset ? '重置' : '删除',
                          role: DialogActionRole.destructive,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    await _save(
      gradient,
      reset
          ? AvatarPaletteStore.defaults(gradient)
          : [
              for (final item in gradient ? _gradients! : _solid!)
                if (item != value) item,
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_solid == null) return const Center(child: CircularProgressIndicator());
    return AbsorbPointer(
      absorbing: _busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(false, _solid!),
          const SizedBox(height: 20),
          _section(true, _gradients!),
        ],
      ),
    );
  }

  Widget _section(bool gradient, List<String> values) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              gradient ? '渐变底色' : '纯色底色',
              style: const TextStyle(fontSize: 15),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 16),
              alignment: Alignment.centerRight,
            ),
            onPressed: () => _remove(gradient, null),
            child: const Text('重置'),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = ((constraints.maxWidth + 6) / 54).floor().clamp(1, 6);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (final value in values)
                Semantics(
                  label: gradient ? '渐变配色' : '纯色配色',
                  selected: widget.selected == value,
                  button: true,
                  onLongPressHint: '删除配色',
                  child: InkResponse(
                    radius: 26,
                    onTap: () => widget.onSelected(value),
                    onLongPress: () => _remove(gradient, value),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 2,
                            color: widget.selected == value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AvatarBackground.decode(value).gradient,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Semantics(
                label: gradient ? '添加渐变' : '添加纯色',
                button: true,
                child: InkResponse(
                  radius: 26,
                  onTap: () => _add(gradient),
                  child: Center(
                    child: CustomPaint(
                      painter: _DashedCircle(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SettingsIcon(type: SettingsIconType.add),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++)
      canvas.drawArc(
        (Offset.zero & size).deflate(1),
        i * math.pi / 6,
        math.pi / 11,
        false,
        pen,
      );
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => color != oldDelegate.color;
}
