import 'package:flutter/material.dart';
import 'settings_icon.dart';

class PrivateTaskListNodes extends StatelessWidget {
  const PrivateTaskListNodes({super.key, required this.steps});
  final List<Map> steps;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < steps.length; index++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: steps[index]['status'] == 'completed'
                            ? SettingsIcon(
                                type: SettingsIconType.check,
                                color: colors.onSurfaceVariant,
                              )
                            : Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        steps[index]['status'] == 'in_progress'
                                        ? colors.onSurface
                                        : null,
                                    border: Border.all(
                                      color:
                                          steps[index]['status'] ==
                                              'in_progress'
                                          ? colors.onSurface
                                          : colors.outlineVariant,
                                      width: 1.65,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 1,
                              color: colors.outlineVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      steps[index]['step'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: steps[index]['status'] == 'in_progress'
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: steps[index]['status'] == 'in_progress'
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
