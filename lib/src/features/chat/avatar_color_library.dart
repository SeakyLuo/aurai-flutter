import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_palette_store.dart';
import 'avatar_background.dart';
import 'avatar_selection_mark.dart';
import 'avatar_color_dialog.dart';
import 'delete_confirmation_dialog.dart';
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
  List<String>? _softs;
  List<String> _values(AvatarPaletteKind kind) => switch (kind) {
    AvatarPaletteKind.solid => _solid!,
    AvatarPaletteKind.soft => _softs!,
    AvatarPaletteKind.gradient => _gradients!,
  };
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
          _softs = lists.softs;
        });
    } catch (caughtError) {
      if (mounted) {
        _notice('配色读取失败：${errorMessage(caughtError)}', kind: ToastKind.error);
        Navigator.pop(context);
      }
    }
  }

  void _notice(String message, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(message)), kind: kind);
  Future<bool> _save(AvatarPaletteKind kind, List<String> values) async {
    setState(() => _busy = true);
    try {
      await _palette.save(kind, values);
      if (!mounted) return false;
      setState(() {
        switch (kind) {
          case AvatarPaletteKind.solid:
            _solid = values;
          case AvatarPaletteKind.soft:
            _softs = values;
          case AvatarPaletteKind.gradient:
            _gradients = values;
        }
      });
      return true;
    } catch (caughtError) {
      if (mounted)
        _notice(
          '配色保存失败，请重试：${errorMessage(caughtError)}',
          kind: ToastKind.error,
        );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(AvatarPaletteKind kind) async {
    final gradient = kind == AvatarPaletteKind.gradient;
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
    final values = _values(kind);
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
    if (await _save(kind, [...values, result]) && mounted)
      widget.onSelected(result);
  }

  Future<void> _remove(AvatarPaletteKind kind, String? value) async {
    final reset = value == null;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: reset ? '重置${kind.label}配色？' : '删除这个配色？',
        description: reset
            ? '恢复本组默认配色并移除本组自定义配色，已使用的头像不变。'
            : '仅从色库移除，已使用的头像不变。',
        confirmLabel: reset ? '重置' : '删除',
      ),
    );
    if (yes != true || !mounted) return;
    await _save(
      kind,
      reset
          ? AvatarPaletteStore.defaults(kind)
          : [
              for (final item in _values(kind))
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
          _section(AvatarPaletteKind.solid, _solid!),
          const SizedBox(height: 20),
          _section(AvatarPaletteKind.soft, _softs!),
          const SizedBox(height: 20),
          _section(AvatarPaletteKind.gradient, _gradients!),
        ],
      ),
    );
  }

  Widget _section(AvatarPaletteKind kind, List<String> values) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${kind.label}底色',
              style: const TextStyle(fontSize: 15),
            ),
          ),

          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 16),
              alignment: Alignment.centerRight,
            ),
            onPressed: () => _remove(kind, null),
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
                  label: '${kind.label}配色',
                  selected: widget.selected == value,
                  button: true,
                  onLongPressHint: '删除配色',
                  child: InkResponse(
                    radius: 26,
                    onTap: () => widget.onSelected(value),
                    onLongPress: () => _remove(kind, value),
                    child: Center(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: AvatarSelectionMark(
                          selected: widget.selected == value,
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
                ),

              Semantics(
                label: '添加${kind.label}',
                button: true,
                child: InkResponse(
                  radius: 26,
                  onTap: () => _add(kind),
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
