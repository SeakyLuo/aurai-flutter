part of 'chat_controller.dart';

extension PrivateGoalActions on ChatController {
  Future<void> editPrivateGoal(
    String conversationId,
    String objective,
    int? tokenBudget,
  ) {
    if (activeConversation.id != conversationId)
      throw StateError('会话已切换，请重新打开目标');
    return _inConversation(activeConversation, () async {
      final store = privateTaskState!;
      if (objective.trim().isEmpty) throw ArgumentError('请输入目标');
      if (tokenBudget != null && tokenBudget <= 0)
        throw ArgumentError('Token 预算必须大于 0');
      final finished = _execution.runFinished?.future;
      if (finished != null) {
        await _stopConversation();
        await finished;
      }
      await store.change((state) {
        if (state['objective'] == null) throw StateError('目标已被清除');
        state['objective'] = objective.trim();
        if (tokenBudget == null) {
          state.remove('tokenBudget');
        } else {
          state['tokenBudget'] = tokenBudget;
        }
        state['status'] = 'paused';
        state['reason'] = '';
        state.remove('blocker');
        state.remove('blockerCount');
        state.remove('blockerTurn');
      });
    });
  }

  Future<void> controlPrivateGoal(String action) => _inConversation(
    activeConversation,
    () async {
      final store = privateTaskState!;
      if (action == 'resume') {
        if (hasRunningTask || _submitting) throw StateError('请等待当前回复结束后继续目标');
        if (needsReplyConfiguration) throw StateError('请先配置模型后再继续目标');
        await store.change((state) {
          if (![
            'paused',
            'blocked',
            'budget_limited',
          ].contains(state['status'])) {
            throw StateError('当前目标无需恢复');
          }
          state['status'] = 'active';
          state['reason'] = '';
          state.remove('blocker');
          state.remove('blockerCount');
          state.remove('blockerTurn');
        });
        pendingGoal = '继续当前目标';
        try {
          await _continuePending();
        } finally {
          await store.pause('执行已停止，等待继续');
        }
        return;
      }
      final state = await store.read();
      if (state['status'] == 'active') {
        final finished = _execution.runFinished?.future;
        await _stopConversation();
        await finished;
      }
      if (action == 'pause') {
        await store.pause('用户暂停了目标');
      } else if (action == 'clear') {
        await store.change((state) {
          state.removeWhere((key, _) => key != 'steps' && key != 'explanation');
        });
      }
    },
  );
}
