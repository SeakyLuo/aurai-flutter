import 'package:flutter/material.dart';

import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

class ModelSearchField extends StatelessWidget {
  const ModelSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    decoration: InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: settingsFieldColor(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      prefixIcon: const Padding(
        padding: EdgeInsets.all(13),
        child: SidebarActionIcon(type: SidebarActionIconType.search),
      ),
    ),
  );
}
