part of 'chat_controller.dart';

class PendingConfirmation {
  PendingConfirmation(this.call, this.definition, this.conversationId)
    : deadline = call.confirmationTimeoutSeconds == null
          ? null
          : DateTime.now().add(
              Duration(seconds: call.confirmationTimeoutSeconds!),
            );
  final String conversationId;
  final DateTime? deadline;
  final ToolCall call;
  final ToolDefinition definition;
  String scope = 'once';
  final completer = Completer<bool>();
}

extension _PendingConfirmationActions on ChatController {
  Future<bool> _confirm(
    ToolCall call,
    ToolDefinition definition, {
    String? runId,
    String? conversationId,
    String senderId = 'agent:aurai',
    bool screenAccess = false,
  }) async {
    if (_removedGroupMembers.contains(senderId) &&
        _groupRuns.containsKey(senderId))
      return false;
    final fingerprint = '$senderId:${call.name}:${jsonEncode(call.arguments)}';
    if (_deniedConfirmations.contains(fingerprint)) return false;
    final accessibilityAvailable = capabilities.any(
      (capability) =>
          capability.id == 'android.accessibility' && capability.isAvailable,
    );
    final approvalId = await _store.runs.requestApproval(
      runId ?? _runningConversation!.activeRunId!,
      call,
      definition,
    );
    conversationId ??= _runningConversation!.id;
    final existing =
        !definition.singleUseConfirmation &&
        ((screenAccess && isScreenTool(call.name)) ||
            toolApprovals.allows(conversationId, call));
    if (!existing)
      await _platform.updateAttentionNotification(
        conversationId,
        'approval',
        title: '等待你的授权',
        body: definition.confirmationDescriptionFor(call.arguments),
        timeoutSeconds: call.confirmationTimeoutSeconds,
      );
    _confirmingSenderId = senderId;
    notifyListeners();
    final bool approved;
    try {
      final scope = accessibilityAvailable && !definition.singleUseConfirmation
          ? await _platform.requestConfirmation(
              call.id,
              call.name,
              call.arguments,
              '${definition.confirmationDescriptionFor(call.arguments) ?? definition.description}\n\n授权对象：${call.name == 'runSkill' ? call.arguments['name'] : toolTitle(call.name)}',
              definition.taskScopedConfirmation,
              call.confirmationTimeoutSeconds,
              autoApproved: existing,
            )
          : existing
          ? 'once'
          : await _confirmInApp(call, definition, conversationId);
      approved = scope != 'deny';
      if (approved && !definition.singleUseConfirmation) {
        await toolApprovals.grant(
          conversationId,
          call,
          call.name == 'runSkill'
              ? '技能：${call.arguments['name']}（版本 ${call.arguments['revision']}）'
              : toolTitle(call.name),
          scope,
        );
      }
    } finally {
      _confirmingSenderId = null;
      notifyListeners();
      await _platform.updateAttentionNotification(conversationId, 'approval');
    }
    await _store.runs.resolveApproval(approvalId, approved);
    if (!approved) _deniedConfirmations.add(fingerprint);
    return approved;
  }

  Future<String> _confirmInApp(
    ToolCall call,
    ToolDefinition definition,
    String conversationId,
  ) async {
    final request = PendingConfirmation(call, definition, conversationId);
    pendingConfirmation = request;
    notifyListeners();
    final timer = call.confirmationTimeoutSeconds == null
        ? null
        : Timer(Duration(seconds: call.confirmationTimeoutSeconds!), () {
            if (identical(pendingConfirmation, request))
              resolveConfirmation(false);
          });
    try {
      final approved = await request.completer.future;
      return approved ? request.scope : 'deny';
    } finally {
      timer?.cancel();
    }
  }
}
