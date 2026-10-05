import '../domain/tool_detail_target.dart';
import '../domain/tool_models.dart';
import 'html_app_data_tool.dart';
import 'html_message_source.dart';

class HtmlAppEditTool implements AgentTool, RuntimeCapabilityAgentTool {
  HtmlAppEditTool(this.name, this.invoke);

  final String name;
  final Future<Map<String, Object?>> Function(String, Map<String, Object?>)
  invoke;
  static const names = ['readHtmlApp', 'updateHtmlApp'];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'readHtmlApp' ? ToolSafety.readOnly : ToolSafety.lowRisk,
    description: name == 'readHtmlApp'
        ? 'Read the source and current version of a miniapp you created or whose development team you joined. Resolve appId with listHtmlApps. Installed copies resolve to the original development source. Read before updateHtmlApp and use the returned appId. If not a member, use requestHtmlAppEdit and wait for approval; readHtmlAppTeam checks membership. No chat launcher is needed.'
        : htmlAppGuide +
              'Modify your persistent miniapp code by appId, without a chat launcher. Requires expectedVersion from readHtmlApp and exactly one of html or sourcePath. Stage changes in a new workspace HTML file, never overwrite the published source in place. Saved data, message state, presentation and library releases are preserved. Open launchers using this app code are notified. This sends no new message. For message state or callback completion use updateHtmlMessage instead. A stale version fails: reread and reconcile before retrying.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'appId': {'type': 'string'},
        if (name == 'updateHtmlApp') ...{
          'expectedVersion': {'type': 'integer', 'minimum': 0},
          'html': {
            'type': ['string', 'null'],
          },
          'sourcePath': HtmlMessageSource.schema,
        },
      },
      'required': ['appId', if (name == 'updateHtmlApp') 'expectedVersion'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final output = await invoke(name, call.arguments);
    return ToolResult(
      callId: call.id,
      toolName: name,
      status: ToolResultStatus.success,
      output: {
        ...output,
        'detailTargets': [
          ToolDetailTarget(
            type: ToolDetailType.miniapp,
            id: output['appId'] as String,
            name: output['title'] as String,
          ).toJson(),
        ],
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
