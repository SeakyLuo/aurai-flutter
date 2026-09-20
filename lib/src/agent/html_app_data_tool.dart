import '../domain/tool_models.dart';

const htmlAppGuide =
    'An HTML message is a launcher referencing a persistent miniapp. Code is stored in an independent application directory, never in the message body. Deleting launchers preserves the app and its data; listHtmlApps finds your apps by title, and sendHtmlMessage with appId reopens the same app. '
    'For application data use await AuraiHTML.readData("career.json") returning {revision,value}; a missing document is {revision:0,value:null}. Save with await AuraiHTML.writeData("career.json",value,revision). Names are flat ASCII JSON filenames (letters, digits, underscore, hyphen), up to 4 MB per document. Do not overwrite a stale revision: reread and reconcile. Both page and AI read/write the same files through readHtmlAppData/writeHtmlAppData. Listen for aurai:messageupdate and reread required documents. Never auto-submit an AI callback in that listener. '
    'AI operations: submitEvent resolves when queued, not when completed. Keep its eventId, disable duplicate submission while queued/processing, and listen for aurai:eventupdate. AuraiHTML.events contains the latest 20 callback statuses (queued/processing/completed/failed); await AuraiHTML.readEvent(eventId) reads one older event, returning null if absent. On reopening, restore status rather than resubmitting. On a deliberate user retry call await AuraiHTML.retryEvent(eventId), which reuses the original payload. Failed includes interrupted or missing result confirmation; do not auto-retry. Statuses belong to the message launcher. AI must call updateHtmlMessage with callbackEventId to confirm completion, including no-change results. Completion and summary update commit together and repeated completion cannot reapply updates. For file data, persist processed event IDs together with results and check them before repeating work: callback completion does not make file writes or external effects exactly-once. '
    'Keep AuraiHTML.messageState for small display summaries (64 KB), and AuraiHTML.state/saveState for legacy local UI state (64 KB). Persistent game history belongs in data documents, not message summaries. Data reads are permitted on load; writes should follow meaningful user actions. Handle read/write failures with a toast and retain edits. Do not silently replace corrupt files with empty data. '
    'Tool output supplies appId/sourcePath/dataDirectory for internal use; do not show them to users. Stage HTML changes in a new shell file and publish with updateHtmlMessage sourcePath; do not edit the active published code file in place. Publishing code preserves data. Data documents use version envelopes internally; write through the data tools rather than shell. The HTML runtime supports HTTPS resources and network requests subject to browser CORS; readData/writeData remain app-scoped data access, not general filesystem access. Forwarding exports HTML source only, not app data or a standalone runnable package. ';

class HtmlAppDataTool implements AgentTool, RuntimeCapabilityAgentTool {
  HtmlAppDataTool(this.name, this.invoke);
  final String name;
  final Future<Map<String, Object?>> Function(String, Map<String, Object?>) invoke;
  static const names = ['listHtmlApps', 'readHtmlAppData', 'writeHtmlAppData'];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'writeHtmlAppData' ? ToolSafety.lowRisk : ToolSafety.readOnly,
    description: name == 'listHtmlApps'
        ? 'Find up to 50 of your persistent miniapps by title, newest first. Apps survive deletion of message launchers. Use the returned appId with sendHtmlMessage to reopen the same app and data. Ask by title/date if ambiguous; never ask users for IDs or paths.'
        : 'Read or write a named JSON data document owned by your miniapp. The HTML page shares these exact documents through AuraiHTML.readData/writeData. Use names such as career.json or season_2026.json. Each document is at most 4 MB. Read returns revision/value; a missing document returns revision 0 and value null. Write requires that revision and atomically replaces the file; stale writes fail. Keep large app data here, not in the 64 KB message summary. Use these tools rather than editing data envelopes through shell. A successful write notifies open app pages; listen for aurai:messageupdate and reread needed data. No AI callback is started by a data write.',
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'listHtmlApps')
          'query': {'type': 'string', 'description': 'Title fragment; empty lists recent apps.'}
        else ...{
          'appId': {'type': 'string'},
          'name': {'type': 'string'},
          if (name == 'writeHtmlAppData') ...{
            'expectedRevision': {'type': 'integer', 'minimum': 0},
            'value': {'description': 'Complete JSON document value.'},
          },
        },
      },
      'required': [
        if (name == 'listHtmlApps') 'query' else ...['appId', 'name'],
        if (name == 'writeHtmlAppData') ...['expectedRevision', 'value'],
      ],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(callId: call.id, toolName: name,
        status: ToolResultStatus.success, output: await invoke(name, call.arguments));
    } on Object catch (error) {
      return ToolResult(callId: call.id, toolName: name,
        status: ToolResultStatus.error,
        output: {'message': error is StateError ? error.message : error.toString()});
    }
  }

  @override
  Future<void> cancel() async {}
}
