import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import '../storage/development_projects.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class ProjectDevelopmentTool implements AgentTool, RuntimeCapabilityAgentTool {
  ProjectDevelopmentTool(this.platform, this.project, this.name);

  final AuraiPlatform platform;
  final DevelopmentProject project;
  final String name;
  String? _activeCallId;

  static const names = [
    'runProjectCommand',
    'getProjectGitStatus',
    'getProjectGitDiff',
    'initializeProjectGit',
    'setProjectGitRemote',
    'commitProjectGit',
    'pullProjectGit',
    'pushProjectGit',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'android.documents',
    description: switch (name) {
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
      _ => throw StateError('Unknown project development tool'),
    },
    inputSchema: {
      'type': 'object',
      'properties': {
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
        if (name == 'runProjectCommand') ...['command', 'timeoutSeconds'],
        if (name == 'setProjectGitRemote') 'url',
        if (name == 'commitProjectGit') 'message',
      ],
      'additionalProperties': false,
    },
    safety: switch (name) {
      'getProjectGitStatus' || 'getProjectGitDiff' => ToolSafety.readOnly,
      _ => ToolSafety.sensitive,
    },
    singleUseConfirmation: name == 'runProjectCommand',
    executionTimeout: const Duration(seconds: 130),
    confirmationDescriptionBuilder: switch (name) {
      'runProjectCommand' =>
        (args) => '在项目“${project.name}”中执行：${args['command']}',
      'initializeProjectGit' => (_) => '在项目“${project.name}”中初始化 Git 仓库。',
      'setProjectGitRemote' =>
        (args) => '将项目“${project.name}”的 origin 设置为 ${args['url']}。',
      'commitProjectGit' =>
        (args) => '提交项目“${project.name}”的全部改动：${args['message']}',
      'pullProjectGit' => (_) => '从 origin 拉取项目“${project.name}”的更新。',
      'pushProjectGit' => (_) => '将项目“${project.name}”的当前分支推送到 origin。',
      _ => null,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    _activeCallId = call.id;
    try {
      final output = await platform
          .deviceExtension('projectDevelopmentOperation', {
            'projectId': project.id,
            'callId': call.id,
            'operation': name,
            'arguments': call.arguments,
          });
      return ToolResult(
        callId: call.id,
        toolName: name,
        output: output,
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
