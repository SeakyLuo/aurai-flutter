import 'package:flutter/material.dart';

/// Keeps departing entries alive while their space collapses.
class AnimatedEntryList extends StatefulWidget {
  const AnimatedEntryList({
    super.key,
    required this.children,
    required this.padding,
    this.controller,
    this.empty,
    this.animateChanges = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final Widget? empty;
  final bool animateChanges;

  @override
  State<AnimatedEntryList> createState() => _AnimatedEntryListState();
}

class _AnimatedEntryListState extends State<AnimatedEntryList> {
  final _list = GlobalKey<AnimatedListState>();
  late final _entries = [...widget.children];
  int _departing = 0;
  static const _duration = Duration(milliseconds: 260);

  @override
  void didUpdateWidget(AnimatedEntryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animateChanges) return;
    final keys = widget.children.map((child) => child.key).toSet();
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (!keys.contains(_entries[i].key)) _remove(i);
    }
    for (var i = 0; i < widget.children.length; i++) {
      final next = widget.children[i];
      if (i < _entries.length && _entries[i].key == next.key) {
        _entries[i] = next;
        continue;
      }
      final previous = _entries.indexWhere((entry) => entry.key == next.key);
      if (previous >= 0) _remove(previous);
      _entries.insert(i, next);
      _list.currentState!.insertItem(i, duration: _duration);
    }
  }

  void _remove(int index) {
    final entry = _entries.removeAt(index);
    _departing++;
    _list.currentState!.removeItem(
      index,
      (context, animation) =>
          IgnorePointer(child: _transition(entry, animation)),
      duration: _duration,
    );
    Future<void>.delayed(_duration, () {
      if (mounted) setState(() => _departing--);
    });
  }

  Widget _transition(Widget child, Animation<double> animation) {
    final curve = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    return SizeTransition(
      sizeFactor: curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curve, child: child),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!widget.animateChanges)
        ListView(
          controller: widget.controller,
          padding: widget.padding,
          children: widget.children,
        )
      else
        AnimatedList(
          key: _list,
          controller: widget.controller,
          padding: widget.padding,
          initialItemCount: _entries.length,
          itemBuilder: (context, index, animation) =>
              _transition(_entries[index], animation),
        ),
      if ((widget.animateChanges
              ? _entries.isEmpty && _departing == 0
              : widget.children.isEmpty) &&
          widget.empty != null)
        Positioned.fill(child: widget.empty!),
    ],
  );
}
