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
  });

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

  Map<String, Object?> toModelJson() => <String, Object?>{
    'status': status.name,
    'result': output,
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
