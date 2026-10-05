part of 'chat_controller.dart';

String _approvalDetail(ToolCall call, ToolDefinition definition) =>
    definition.confirmationDescriptionFor(call.arguments) ??
    switch (call.name) {
      'shell' => '将以 Aurai 自身权限执行命令：\n${call.arguments['command']}',
      'startIntent' =>
        '将启动 Android 操作：\n${['Action: ${call.arguments['action']}', if (call.arguments['data'] != null) 'Data: ${call.arguments['data']}', if (call.arguments['mimeType'] != null) 'Type: ${call.arguments['mimeType']}', if (call.arguments['packageName'] != null) 'App: ${call.arguments['packageName']}', if (call.arguments['extras'] != null) 'Extras: ${call.arguments['extras']}'].join('\n')}',
      'act' when call.arguments['action'] == 'inputText' =>
        '将输入文字：\n${call.arguments['text']}',
      'act' => switch (call.arguments['action']) {
        'click' => '将点击当前屏幕中选定的控件。',
        'scroll' => '将滚动当前页面。',
        'back' => '将返回上一页。',
        'home' => '将返回手机主屏幕。',
        _ => '将操作当前屏幕中选定的控件。',
      },
      _ => definition.description,
    };

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
      final request = existing
          ? Future.value('once')
          : _confirmInApp(
              approvalId,
              call,
              definition,
              conversationId,
              senderId,
              senderName,
              label,
              native:
                  accessibilityAvailable &&
                  isScreenTool(call.name) &&
                  !definition.singleUseConfirmation,
            );
      var scope = cancellation == null
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
      if (scope == 'deny') await request;
      // Native screen actions still validate their observation and issue a
      // one-use execution token after the user has approved in the app.
      if (scope != 'deny' &&
          accessibilityAvailable &&
          isScreenTool(call.name)) {
        final nativeScope = await _platform.requestConfirmation(
          call.id,
          call.name,
          call.arguments,
          definition.confirmationDescriptionFor(call.arguments),
          definition.taskScopedConfirmation,
          call.confirmationTimeoutSeconds,
          autoApproved: true,
        );
        if (nativeScope == 'deny') scope = 'deny';
      }
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
    int approvalId,
    ToolCall call,
    ToolDefinition definition,
    String conversationId,
    String senderId,
    String senderName,
    String label, {
    required bool native,
  }) async {
    final request = PendingConfirmation(
      call,
      definition,
      conversationId,
      senderId,
      senderName,
      label,
    );
    final confirmation = _execution.requestConfirmation(request);
    final id = 'tool:$approvalId';
    final db = _store.database;
    var nativeSettled = false;
    var nativePending = false;
    Future<void>? nativeWait;
    (Object, StackTrace)? nativeFailure;
    try {
      await ApprovalCenterStore.insert(db, {
        'id': id,
        'kind': 'tool',
        'title': toolTitle(call.name),
        'description': _approvalDetail(call, definition),
        'sender_name': senderName,
        'sender_id': senderId,
        'requested_at': DateTime.now().microsecondsSinceEpoch,
        'deadline': request.deadline?.microsecondsSinceEpoch,
        'allow_scopes': definition.singleUseConfirmation ? 0 : 1,
      });
      ApprovalCenterStore.liveTools[id] = (scope) async {
        if (request.completer.isCompleted) throw StateError('此任务已结束');
        if (request.deadline != null &&
            !DateTime.now().isBefore(request.deadline!)) {
          throw StateError('此申请已超时');
        }
        nativeSettled = true;
        await ApprovalCenterStore.finish(
          db,
          id,
          scope == 'deny' ? 'denied' : 'approved',
          scope: scope,
        );
        request.scope = scope;
        if (!request.completer.isCompleted)
          request.completer.complete(scope != 'deny');
      };
      if (native) {
        nativePending = true;
        nativeWait = () async {
          try {
            final scope = await _platform.requestConfirmation(
              call.id,
              call.name,
              call.arguments,
              '${definition.confirmationDescriptionFor(call.arguments) ?? definition.description}\n\n执行者：$senderName',
              definition.taskScopedConfirmation,
              call.confirmationTimeoutSeconds,
            );
            nativePending = false;
            if (nativeSettled || request.completer.isCompleted) return;
            nativeSettled = true;
            await ApprovalCenterStore.finish(
              db,
              id,
              request.deadline != null &&
                      !DateTime.now().isBefore(request.deadline!)
                  ? 'expired'
                  : scope == 'deny'
                  ? 'denied'
                  : 'approved',
              scope: scope,
            );
            request.scope = scope;
            if (!request.completer.isCompleted)
              request.completer.complete(scope != 'deny');
          } on Object catch (error, stack) {
            nativeFailure = (error, stack);
            if (!request.completer.isCompleted)
              request.completer.completeError(error, stack);
          }
        }();
        ApprovalCenterStore.changes.add(null);
      } else {
        ApprovalCenterStore.announce(id);
      }
      notifyListeners();
      return await confirmation;
    } finally {
      if (identical(pendingConfirmation, request))
        _execution.resolveConfirmation(false);
      nativeSettled = true;
      if (nativePending) await _platform.cancelPendingInteraction();
      await nativeWait;
      ApprovalCenterStore.liveTools.remove(id);
      await ApprovalCenterStore.finish(
        db,
        id,
        request.deadline != null && !DateTime.now().isBefore(request.deadline!)
            ? 'expired'
            : 'cancelled',
      );
      ApprovalCenterStore.changes.add(null);
      notifyListeners();
      if (nativeFailure case final failure?) {
        Error.throwWithStackTrace(failure.$1, failure.$2);
      }
    }
  }
}
