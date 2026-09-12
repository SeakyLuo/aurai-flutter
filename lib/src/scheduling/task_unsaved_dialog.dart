import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/settings_appearance.dart';
import '../utils/widget_utils.dart';

class TaskUnsavedDialog extends StatelessWidget {
  const TaskUnsavedDialog({super.key, this.description = '任务还有未保存的修改。'});
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = TextButton.styleFrom(
      minimumSize: const Size(double.infinity, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
    );
    return Dialog(
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
                  '保存修改？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                WidgetUtils.primaryButton(
                  text: '保存',
                  height: 46,
                  onPressed: () => Navigator.pop(context, 'save'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'discard'),
                  style: style.merge(
                    TextButton.styleFrom(
                      foregroundColor: dark
                          ? const Color(0xffff8a80)
                          : const Color(0xffd93025),
                      backgroundColor: dialogControlColor(context),
                    ),
                  ),
                  child: const Text('放弃修改'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: style.merge(
                    TextButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      backgroundColor: dialogControlColor(context),
                    ),
                  ),
                  child: const Text('继续编辑'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
