import 'package:flutter/material.dart';
import 'settings_icon.dart';

class ListSortHandle extends StatelessWidget {
  const ListSortHandle({super.key, required this.index, required this.enabled});
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    enabled: enabled,
    child: const Tooltip(
      message: '拖动排序',
      child: SizedBox.square(
        dimension: 40,
        child: Center(child: SettingsIcon(type: SettingsIconType.drag)),
      ),
    ),
  );
}
