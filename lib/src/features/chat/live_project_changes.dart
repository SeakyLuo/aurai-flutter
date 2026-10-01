part of 'chat_controller.dart';

extension LiveProjectChangeState on ChatController {
  List<LiveProjectChanges> get liveProjectChanges {
    final latest = <String, LiveProjectChanges>{};
    for (final run in _viewExecution.liveProjectChanges.values) {
      for (final change in run) {
        latest[change.workspaceId] = change;
      }
    }
    return latest.values.toList();
  }

  Future<void> _updateLiveProjectChanges(
    ProjectRunSnapshots snapshots,
    ToolResult result,
    String runId,
  ) async {
    if (result.status == ToolResultStatus.denied ||
        !const {
          'runProjectCommand',
          'shell',
          'executeShizuku',
          'executeAndroidScript',
          'runSkill',
          'writeTextFile',
          'replaceText',
          'applyTextPatch',
          'createTextFile',
          'renameDocument',
          'copyDocument',
          'moveDocument',
          'deleteDocument',
        }.contains(result.toolName))
      return;
    final changes = await snapshots.preview();
    _execution.liveProjectChanges.remove(runId);
    _execution.liveProjectChanges[runId] = changes;
    notifyListeners();
  }

  Future<void> _finishLiveProjectChanges(
    ProjectRunSnapshots snapshots,
    String runId,
  ) async {
    try {
      await snapshots.abort();
    } finally {
      _execution.liveProjectChanges.remove(runId);
      notifyListeners();
    }
  }
}
