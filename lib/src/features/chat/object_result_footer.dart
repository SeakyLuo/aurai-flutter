import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/tool_detail_target.dart';
import 'object_detail_navigation.dart';
import 'result_detail_link.dart';

class ObjectResultFooter extends StatelessWidget {
  const ObjectResultFooter({super.key, required this.resultJson});
  final String resultJson;
  @override
  Widget build(BuildContext context) {
    final targets = (jsonDecode(resultJson) as Map)['detailTargets'] as List?;
    if (targets == null) return const SizedBox.shrink();
    return Column(
      children: [
        for (final json in targets)
          _link(
            context,
            ToolDetailTarget.fromJson(Map<String, dynamic>.from(json as Map)),
          ),
      ],
    );
  }

  Widget _link(BuildContext context, ToolDetailTarget target) =>
      ResultDetailLink(
        icon: objectDetailIcon(context, target),
        name: target.name,
        open: () => openObjectDetail(context, target),
      );
}
