import 'dart:convert';
import 'line_change_count.dart';

enum ToolSafety { readOnly, lowRisk, sensitive, destructive }

enum ToolResultStatus { success, error, denied, cancelled }

typedef ToolConfirmationDescriptionBuilder =
    String Function(Map<String, Object?> arguments);

class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.safety,
    required this.capabilityId,
    this.actionArgument,
    this.actionSafety = const <String, ToolSafety>{},
    this.executionTimeout = const Duration(seconds: 12),
    this.confirmationDescription,
    this.confirmationDescriptionBuilder,
    this.taskScopedConfirmation = false,
    this.confirmationMayBeRequired = false,
    this.singleUseConfirmation = false,
    this.waitsForUser = false,
    this.authorizationScope,
    this.authorizationLabel,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final ToolSafety safety;
  final String capabilityId;
  final String? actionArgument;
  final Map<String, ToolSafety> actionSafety;
  final Duration executionTimeout;
  final String? confirmationDescription;
  final ToolConfirmationDescriptionBuilder? confirmationDescriptionBuilder;
  final bool taskScopedConfirmation;
  final bool confirmationMayBeRequired;
  final bool singleUseConfirmation;
  final bool waitsForUser;
  final String? authorizationScope;
  final String? authorizationLabel;

  Map<String, Object?> get modelInputSchema {
    final needsConfirmation = [safety, ...actionSafety.values].any(
      (value) =>
          value == ToolSafety.sensitive || value == ToolSafety.destructive,
    );
    final confirmation = needsConfirmation || confirmationMayBeRequired;
    final handoff = !waitsForUser;
    return {
      ...inputSchema,
      'properties': {
        ...(inputSchema['properties'] as Map),
        if (handoff)
          'userAction': {
            'type': ['string', 'null'],
            'minLength': 1,
            'maxLength': 600,
            'description':
                '只有工具成功后仍需要人类亲自完成操作（如登录、扫码、选择授权文件夹）时，才填写具体说明：在哪里、做什么、完成后如何返回。填写字符串会立即触发“等待你操作”面板并暂停执行，不是备注或状态文案。无需人类接手（如发消息、搜索、读取、等待）时传 JSON null，例如 {"userAction": null}；绝不能传 {"userAction": "null"}、空字符串或笼统的“请操作”。需要接手的示例：{"userAction": "请在打开的登录页完成登录，然后返回 App 点已完成"}。已有独立等待流程时不要重复交接。这不是权限审批；用户确认后仍须核实实际结果。',
          },
        if (confirmation)
          'confirmationTimeoutSeconds': {
            'type': ['integer', 'null'],
            'minimum': 1,
            'description':
                'Use null to wait until the user answers, without a deadline. Set a positive number of seconds only when a timeout is needed. On timeout the app rejects the operation; timeout never grants permission.',
          },
      },
      'required': [
        ...(inputSchema['required'] as List? ?? const []),
        if (handoff) 'userAction',
        if (confirmation) 'confirmationTimeoutSeconds',
      ],
    };
  }

  String? confirmationDescriptionFor(Map<String, Object?> arguments) =>
      confirmationDescriptionBuilder?.call(arguments) ??
      confirmationDescription;

  ToolSafety safetyFor(Map<String, Object?> arguments) {
    final key = actionArgument;
    if (key == null) return safety;
    return actionSafety[arguments[key]] ?? safety;
  }
}

enum ToolAttachmentType { image }

class ToolAttachment {
  const ToolAttachment({
    required this.type,
    required this.mimeType,
    required this.base64Data,
    this.detail = 'low',
  });

  final ToolAttachmentType type;
  final String mimeType;
  final String base64Data;
  final String detail;
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.confirmationTimeoutSeconds,
    this.userAction,
    this.argumentsError,
  });

  factory ToolCall.fromJsonArguments({
    required String id,
    required String name,
    required String arguments,
  }) {
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('工具参数必须是 JSON 对象');
      }
      return ToolCall.fromModel(id: id, name: name, arguments: decoded);
    } on FormatException catch (error) {
      final offset = error.offset;
      final start = offset == null
          ? 0
          : (offset - 100).clamp(0, arguments.length);
      final end = offset == null
          ? arguments.length.clamp(0, 200)
          : (offset + 100).clamp(0, arguments.length);
      return ToolCall(
        id: id,
        name: name,
        arguments: {'invalidJson': arguments},
        argumentsError:
            '${error.message}'
            '${offset == null ? '' : '（位置 $offset）'}'
            '\n出错附近的原始 JSON（片段起点 $start）：'
            '${jsonEncode(arguments.substring(start, end))}',
      );
    }
  }

  factory ToolCall.fromModel({
    required String id,
    required String name,
    required Map<String, Object?> arguments,
  }) {
    final executionArguments = Map<String, Object?>.of(arguments);
    final timeout = executionArguments.remove('confirmationTimeoutSeconds');
    final userAction = executionArguments.remove('userAction');
    final argumentErrors = <String>[
      if (timeout != null && timeout is! int)
        'confirmationTimeoutSeconds 必须是整数或 null',
      if (userAction != null && userAction is! String)
        'userAction 必须是字符串或 null',
    ];
    return ToolCall(
      id: id,
      name: name,
      arguments: executionArguments,
      confirmationTimeoutSeconds: timeout is int ? timeout : null,
      userAction: userAction is String ? userAction : null,
      argumentsError: argumentErrors.isEmpty
          ? null
          : '工具参数不符合 schema：${argumentErrors.join('；')}',
    );
  }

  final String? argumentsError;
  final int? confirmationTimeoutSeconds;
  final String? userAction;
  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

class ToolResult {
  const ToolResult({
    required this.callId,
    required this.toolName,
    required this.status,
    required this.output,
    this.attachments = const <ToolAttachment>[],
  });

  final String callId;
  final String toolName;
  final ToolResultStatus status;
  final Map<String, Object?> output;
  final List<ToolAttachment> attachments;

  Map<String, Object?> get modelOutput {
    final changes = output['fileChanges'] as List?;
    if (changes == null) return output;
    return {
      ...output,
      'fileChanges': [
        for (final row in changes.cast<Map>()) _fileChangeForModel(row),
      ],
    };
  }

  Map<String, Object?> _fileChangeForModel(Map row) {
    final before = (row['beforeLines'] as List?)?.cast<String>();
    final after = (row['afterLines'] as List?)?.cast<String>();
    final count = before == null || after == null
        ? null
        : countLineChanges(before, after);
    return {
      for (final entry in row.entries)
        if (entry.key != 'beforeLines' && entry.key != 'afterLines')
          entry.key as String: entry.value,
      if (count != null) 'addedLines': count.added,
      if (count != null) 'removedLines': count.removed,
    };
  }

  Map<String, Object?> toModelJson() => <String, Object?>{
    'status': status.name,
    'result': modelOutput,
  };
}

abstract interface class AgentTool {
  ToolDefinition get definition;

  Future<ToolResult> execute(ToolCall call);

  Future<void> cancel();
}

abstract interface class PreflightAgentTool {
  Future<ToolResult?> preflight(ToolCall call);
}

abstract interface class RuntimeCapabilityAgentTool {}

abstract interface class ScopedAuthorizationAgentTool {
  Object authorizationScope(ToolCall call);

  bool authorizationCovers(Object grantedScope, Object requestedScope);
}

/// Presentation snapshots for local history, never execution arguments.
abstract interface class ToolHistoryAgentTool {
  Map<String, Object?> historyArguments(ToolCall call);
}

abstract interface class ToolConfirmationPolicyAgentTool {
  bool requiresConfirmation(ToolCall call);
}
