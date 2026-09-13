import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class WaitForUiTool implements AgentTool {
  WaitForUiTool(this.platform);
  final AuraiPlatform platform;
  Completer<void>? _cancelled;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'waitForUi',
    description:
        '等待目标应用的无障碍界面变化，最多 30 秒，每 500 毫秒检查一次，可取消。先 observeDevice 获取 packageName 和 observationId。condition 为 textAppears（文字出现）、textDisappears（文字消失）或 pageChanges（相对之前 observationId 页面变化）。文字按大小写敏感的子串匹配节点文本和描述；消失需要完整界面树连续两次未匹配。文本条件填 text，页面变化填 observationId，其他填 null。只检测无障碍树，不截图；变化不代表加载或任务成功。matched=false 时不得声称完成，不自动重复等待或申请权限。返回最后观察供后续判断。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'condition': {
          'type': 'string',
          'enum': ['textAppears', 'textDisappears', 'pageChanges'],
        },
        'packageName': {'type': 'string', 'minLength': 1},
        'text': {
          'type': ['string', 'null'],
          'minLength': 1,
          'maxLength': 200,
        },
        'observationId': {
          'type': ['string', 'null'],
          'minLength': 1,
        },
        'timeoutSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 30},
      },
      'required': [
        'condition',
        'packageName',
        'text',
        'observationId',
        'timeoutSeconds',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.observe',
    executionTimeout: Duration(seconds: 35),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final args = call.arguments;
    final condition = args['condition'] as String;
    final text = args['text'] as String?;
    final baseline = args['observationId'] as String?;
    final seconds = args['timeoutSeconds'] as int;
    final watch = Stopwatch()..start();
    final cancelled = Completer<void>();
    _cancelled = cancelled;
    Map<String, Object?>? last;
    ToolResult result(
      Map<String, Object?> output, {
      ToolResultStatus status = ToolResultStatus.success,
    }) => ToolResult(
      callId: call.id,
      toolName: call.name,
      status: status,
      output: {
        'matched': false,
        'elapsedMs': watch.elapsedMilliseconds,
        ...output,
      },
    );
    try {
      if (seconds < 1 ||
          seconds > 30 ||
          ![
            'textAppears',
            'textDisappears',
            'pageChanges',
          ].contains(condition) ||
          (condition == 'pageChanges'
              ? baseline == null || baseline.isEmpty
              : text == null || text.isEmpty)) {
        return result({
          'error': '请提供有效的等待条件和 1–30 秒超时',
        }, status: ToolResultStatus.error);
      }
      var absentCount = 0;
      while (!cancelled.isCompleted &&
          watch.elapsedMilliseconds < seconds * 1000) {
        last = await Future.any<Map<String, Object?>?>([
          platform.observeDevice(),
          cancelled.future.then((_) => null),
        ]);
        if (cancelled.isCompleted) break;
        final ui = last!['ui'] as Map;
        if (ui['accessibilityAvailable'] != true) {
          return result({
            'error': '无障碍服务不可用，无法等待界面变化',
            'observation': last,
          }, status: ToolResultStatus.error);
        }
        final nodes = ui['nodes'] as List;
        final inTarget =
            ui['packageName'] == args['packageName'] && nodes.isNotEmpty;
        var matched = false;
        if (inTarget) {
          if (condition == 'pageChanges') {
            matched = ui['observationId'] != baseline;
          } else {
            final found = nodes.cast<Map>().any(
              (node) =>
                  node['password'] != true &&
                  [
                    node['text'],
                    node['description'],
                  ].whereType<String>().any((value) => value.contains(text!)),
            );
            absentCount = !found && ui['truncated'] == false
                ? absentCount + 1
                : 0;
            matched = condition == 'textAppears' ? found : absentCount >= 2;
          }
        } else {
          absentCount = 0;
        }
        if (matched) return result({'matched': true, 'observation': last});
        final remaining = seconds * 1000 - watch.elapsedMilliseconds;
        if (remaining <= 0) break;
        await Future.any<void>([
          Future<void>.delayed(
            Duration(milliseconds: remaining < 500 ? remaining : 500),
          ),
          cancelled.future,
        ]);
      }
      return result(
        {
          'cancelled': cancelled.isCompleted,
          'timedOut': !cancelled.isCompleted,
          if (last != null) 'observation': last,
        },
        status: cancelled.isCompleted
            ? ToolResultStatus.cancelled
            : ToolResultStatus.success,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    } finally {
      _cancelled = null;
    }
  }

  @override
  Future<void> cancel() async {
    final pending = _cancelled;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}
