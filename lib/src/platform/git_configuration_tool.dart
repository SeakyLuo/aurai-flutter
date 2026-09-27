import '../domain/tool_models.dart';
import 'aurai_platform.dart';

class GitConfigurationTool implements AgentTool, RuntimeCapabilityAgentTool {
  GitConfigurationTool(this.platform, this.update);

  final AuraiPlatform platform;
  final bool update;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: update ? 'updateGitConfiguration' : 'readGitConfiguration',
    capabilityId: 'local.git',
    safety: update ? ToolSafety.sensitive : ToolSafety.readOnly,
    description: update
        ? '更新全局 Git 提交身份、默认分支和 HTTPS 认证。先调用 readGitConfiguration。httpsToken 为 null 时保留已有令牌，传入非空字符串时替换；clearHttpsToken 为 true 时清除。令牌保存后不会回显。'
        : '读取全局 Git 提交身份、默认分支和 HTTPS 用户名，以及令牌是否已配置。不会返回令牌内容。',
    inputSchema: {
      'type': 'object',
      'properties': update
          ? {
              'name': {'type': 'string', 'maxLength': 200},
              'email': {'type': 'string', 'maxLength': 320},
              'defaultBranch': {
                'type': 'string',
                'minLength': 1,
                'maxLength': 200,
              },
              'httpsUsername': {'type': 'string', 'maxLength': 200},
              'httpsToken': {
                'type': ['string', 'null'],
                'maxLength': 2000,
              },
              'clearHttpsToken': {'type': 'boolean'},
            }
          : <String, Object?>{},
      'required': update
          ? [
              'name',
              'email',
              'defaultBranch',
              'httpsUsername',
              'httpsToken',
              'clearHttpsToken',
            ]
          : <String>[],
      'additionalProperties': false,
    },
    confirmationDescriptionBuilder: update
        ? (_) => '更新全局 Git 身份、默认分支和 HTTPS 认证设置。'
        : null,
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final output = update
        ? await platform.deviceExtension('setGitConfiguration', {
            'configuration': call.arguments,
          })
        : await platform.deviceExtension('getGitConfiguration');
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: output,
    );
  }

  @override
  Future<void> cancel() async {}
}
