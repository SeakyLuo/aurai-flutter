import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/tool_detail_target.dart';
import 'object_detail_navigation.dart';
import 'question_icon.dart';
import 'result_detail_link.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ObjectResultFooter extends StatelessWidget {
  const ObjectResultFooter({super.key, required this.resultJson});
  final String resultJson;
  @override
  Widget build(BuildContext context) {
    final rows = (jsonDecode(resultJson) as Map)['detailTargets'] as List?;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final targets = [
      for (final json in rows)
        ToolDetailTarget.fromJson(Map<String, dynamic>.from(json as Map)),
    ];
    return ResultDetailLink(
      icon: objectDetailIcon(context, targets.first),
      name: '查看详情',
      open: () async {
        final target = targets.length == 1
            ? targets.single
            : await showModalBottomSheet<ToolDetailTarget>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: false,
                builder: (_) => _ResultTargetsSheet(targets: targets),
              );
        if (target != null && context.mounted) {
          await openObjectDetail(context, target);
        }
      },
    );
  }
}

class _ResultTargetsSheet extends StatelessWidget {
  const _ResultTargetsSheet({required this.targets});
  final List<ToolDetailTarget> targets;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: GlobalUI.bottomSheetBorderRadius,
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '查看详情（${targets.length}）',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    leading: objectDetailIcon(context, target),
                    title: Text(target.name),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: () => Navigator.pop(context, target),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
