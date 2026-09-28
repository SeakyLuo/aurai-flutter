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
    safety: update ? ToolSafety.lowRisk : ToolSafety.readOnly,
    description: update
        ? '更新全局 Git 提交身份、默认分支和按域名保存的 HTTPS 凭据。先调用 readGitConfiguration。Codeup 和 GitHub 的 username 可留空，Aurai 会自动处理；凭据 token 为 null 时保留该域名已有令牌，传入非空字符串时替换；从列表移除凭据会删除它。令牌保存后不会回显。'
        : '读取全局 Git 提交身份、默认分支和按域名保存的 HTTPS 凭据，以及各令牌是否已配置。不会返回令牌内容。',
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
              'httpsCredentials': {
                'type': 'array',
                'maxItems': 20,
                'items': {
                  'type': 'object',
                  'properties': {
                    'host': {'type': 'string', 'maxLength': 253},
                    'username': {'type': 'string', 'maxLength': 200},
                    'token': {
                      'type': ['string', 'null'],
                      'maxLength': 2000,
                    },
                  },
                  'required': ['host', 'username', 'token'],
                  'additionalProperties': false,
                },
              },
            }
          : <String, Object?>{},
      'required': update
          ? ['name', 'email', 'defaultBranch', 'httpsCredentials']
          : <String>[],
      'additionalProperties': false,
    },
    confirmationDescriptionBuilder: update
        ? (_) => '更新全局 Git 身份、默认分支和 HTTPS 凭据。'
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
