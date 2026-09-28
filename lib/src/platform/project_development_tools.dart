import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import '../storage/development_projects.dart';
import '../storage/project_directory.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class ProjectDevelopmentTool implements AgentTool, RuntimeCapabilityAgentTool {
  ProjectDevelopmentTool(
    this.platform,
    this.project,
    this.name, {
    this.onGitBaseChanged,
  });

  final AuraiPlatform platform;
  final DevelopmentProject project;
  final String name;
  final Future<void> Function(ProjectDirectory directory)? onGitBaseChanged;
  String? _activeCallId;
  ProjectDirectory _directory(Map<String, dynamic> args) {
    final matches = project.directories.where(
      (directory) => directory.uri == args['directoryUri'] && directory.managed,
    );
    if (matches.isEmpty) throw StateError('目标目录不属于本项目的 Aurai 工作区');
    return matches.single;
  }

  static const names = [
    'runProjectCommand',
    'getProjectGitStatus',
    'getProjectGitDiff',
    'initializeProjectGit',
    'setProjectGitRemote',
    'commitProjectGit',
    'pullProjectGit',
    'pushProjectGit',
    'mergeProjectBranch',
    'checkoutProjectBranch',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'android.documents',
    description: switch (name) {
      'checkoutProjectBranch' =>
        '将项目主目录切换到指定已有本地分支，要求工作目录干净；不能切换到已被工作树占用的分支。工作树自身固定分支，使用 mergeProjectBranch 同步。',
      'runProjectCommand' =>
        '在当前 Aurai 托管项目目录中执行一条 shell 命令，返回退出码和输出。适合构建、格式化、代码生成与项目检查；每次执行都需要用户确认。',
      'getProjectGitStatus' => '读取当前 Aurai 托管项目的 Git 分支、远端和文件状态。',
      'getProjectGitDiff' => '读取当前 Aurai 托管项目暂存区及工作区的统一 diff。',
      'initializeProjectGit' => '在当前 Aurai 托管项目中初始化 Git 仓库。',
      'setProjectGitRemote' =>
        '设置当前 Aurai 托管项目的 origin，支持 HTTPS、ssh:// 和 git@host:path。',
      'commitProjectGit' => '暂存当前项目的全部改动并创建一次 Git 提交。',
      'pullProjectGit' => '从当前项目的 origin 拉取并合并远端改动。',
      'pushProjectGit' => '将当前项目分支推送到 origin。',
      'mergeProjectBranch' =>
        '把指定本地分支合并到当前工作树或主目录，要求先提交当前修改。可用于工作树同步主分支。返回冲突文件；处理冲突后使用 commitProjectGit 完成合并，非快进合并也需提交。',
      _ => throw StateError('Unknown project development tool'),
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        'directoryUri': {
          'type': 'string',
          'description':
              '目标目录 URI，必须来自本项目已关联的 Aurai 工作目录。每次调用明确指定，可在同轮任务中操作不同目录。',
        },
        if (name == 'checkoutProjectBranch')
          'branch': {'type': 'string', 'minLength': 1},
        if (name == 'mergeProjectBranch')
          'branch': {'type': 'string', 'minLength': 1},
        if (name == 'runProjectCommand') ...{
          'command': {'type': 'string', 'minLength': 1, 'maxLength': 4000},
          'timeoutSeconds': {'type': 'integer', 'minimum': 1, 'maximum': 120},
        },
        if (name == 'setProjectGitRemote')
          'url': {'type': 'string', 'minLength': 1, 'maxLength': 1000},
        if (name == 'commitProjectGit')
          'message': {'type': 'string', 'minLength': 1, 'maxLength': 500},
      },
      'required': [
        'directoryUri',
        if (name == 'checkoutProjectBranch') 'branch',
        if (name == 'mergeProjectBranch') 'branch',
        if (name == 'runProjectCommand') ...['command', 'timeoutSeconds'],
        if (name == 'setProjectGitRemote') 'url',
        if (name == 'commitProjectGit') 'message',
      ],
      'additionalProperties': false,
    },
    safety: switch (name) {
      'getProjectGitStatus' || 'getProjectGitDiff' => ToolSafety.readOnly,
      'runProjectCommand' => ToolSafety.sensitive,
      _ => ToolSafety.lowRisk,
    },
    singleUseConfirmation: name == 'runProjectCommand',
    executionTimeout: const Duration(seconds: 130),
    confirmationDescriptionBuilder: switch (name) {
      'checkoutProjectBranch' =>
        (args) => '将目录“${_directory(args).name}”切换到 ${args['branch']}。',
      'runProjectCommand' =>
        (args) => '在目录“${_directory(args).name}”中执行：${args['command']}',
      'initializeProjectGit' =>
        (args) => '在目录“${_directory(args).name}”中初始化 Git 仓库。',
      'setProjectGitRemote' =>
        (args) => '将目录“${_directory(args).name}”的 origin 设置为 ${args['url']}。',
      'commitProjectGit' =>
        (args) => '提交目录“${_directory(args).name}”的全部改动：${args['message']}',
      'pullProjectGit' =>
        (args) => '从 origin 拉取目录“${_directory(args).name}”的更新。',
      'pushProjectGit' =>
        (args) => '将目录“${_directory(args).name}”的当前分支推送到 origin。',
      'mergeProjectBranch' =>
        (args) => '将分支 ${args['branch']} 合并到目录“${_directory(args).name}”。',
      _ => null,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final directory = _directory(call.arguments);
    _activeCallId = call.id;
    try {
      final output = await platform
          .deviceExtension('projectDevelopmentOperation', {
            'projectId': directory.workspaceId,
            'callId': call.id,
            'operation': name,
            'arguments': call.arguments,
          });
      final baseChanged = switch (name) {
        'pullProjectGit' => output['pulled'] == true,
        'checkoutProjectBranch' => output['switched'] == true,
        'mergeProjectBranch' => output['merged'] == true,
        _ => false,
      };
      if (baseChanged) {
        await onGitBaseChanged?.call(directory);
      }
      return ToolResult(
        callId: call.id,
        toolName: name,
        output: {
          ...output,
          'workspaceRoot': directory.uri,
          'workspaceName': directory.name,
        },
        status: ToolResultStatus.success,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    } finally {
      if (_activeCallId == call.id) _activeCallId = null;
    }
  }

  @override
  Future<void> cancel() async {
    final callId = _activeCallId;
    if (callId == null) return;
    await platform.deviceExtension('cancelProjectDevelopmentOperation', {
      'callId': callId,
    });
  }
}
