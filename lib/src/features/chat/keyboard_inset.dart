import 'package:flutter/material.dart';

class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: enabled ? MediaQuery.viewInsetsOf(context).bottom : 0,
    ),
    child: child,
  );
}
