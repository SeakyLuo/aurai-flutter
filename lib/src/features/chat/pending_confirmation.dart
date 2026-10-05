part of 'chat_controller.dart';

extension _PendingConfirmationActions on ChatController {
  Future<bool> _confirm(
    ToolCall call,
    ToolDefinition definition, {
    String? runId,
    String? conversationId,
    String senderId = 'agent:aurai',
    bool screenAccess = false,
    String? taskTitle,
    Future<void>? cancellation,
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
            toolApprovals.allows(conversationId, call, senderId, definition));
    final sender = (await _store.database.query(
      'message_senders',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [senderId],
      limit: 1,
    )).single;
    final senderName = taskTitle == null
        ? sender['name'] as String
        : '${sender['name']} · $taskTitle';
    final label =
        '$senderName · ${definition.authorizationLabel ?? (call.name == 'runSkill' ? '技能：${call.arguments['name']}（版本 ${call.arguments['revision']}）' : toolTitle(call.name))}';
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
    var resolved = false;
    try {
      final request =
          accessibilityAvailable && !definition.singleUseConfirmation
          ? _platform.requestConfirmation(
              call.id,
              call.name,
              call.arguments,
              '${definition.confirmationDescriptionFor(call.arguments) ?? definition.description}\n\n执行者：$senderName',
              definition.taskScopedConfirmation,
              call.confirmationTimeoutSeconds,
              autoApproved: existing,
            )
          : existing
          ? Future.value('once')
          : _confirmInApp(
              call,
              definition,
              conversationId,
              senderId,
              senderName,
              label,
            );
      final scope = cancellation == null
          ? await request
          : await Future.any([
              request,
              cancellation.then((_) async {
                if (!resolved) {
                  if (identical(pendingConfirmation?.call, call))
                    _execution.resolveConfirmation(false);
                  if (accessibilityAvailable)
                    await _platform.cancelPendingInteraction();
                }
                return 'deny';
              }),
            ]);
      resolved = true;
      approved = scope != 'deny';
      if (approved && !definition.singleUseConfirmation) {
        await toolApprovals.grant(
          conversationId,
          call,
          label,
          scope,
          senderId,
          definition,
        );
      }
    } finally {
      resolved = true;
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
    String senderId,
    String senderName,
    String label,
  ) async {
    final request = PendingConfirmation(
      call,
      definition,
      conversationId,
      senderId,
      senderName,
      label,
    );
    return _execution.requestConfirmation(request);
  }
}
