import 'package:flutter/material.dart';

class KeyboardInset extends StatelessWidget {
  const KeyboardInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
}
