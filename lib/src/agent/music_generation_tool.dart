import '../domain/tool_models.dart';
import '../providers/music_generation_client.dart';

class MusicGenerationTool implements AgentTool, RuntimeCapabilityAgentTool {
  MusicGenerationTool(this.run, {required this.configured});

  final bool Function() configured;
  final Future<Map<String, Object?>> Function(
    Map<String, Object?> arguments,
    MusicGenerationClient client,
  )
  run;
  MusicGenerationClient? _client;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'generateMusic',
    capabilityId: 'music.generate',
    safety: ToolSafety.lowRisk,
    executionTimeout: const Duration(minutes: 8),
    description:
        '${configured() ? '' : 'Music generation is not configured. Open the music settings and wait for the user to enter a separate API key. '}'
        'Generate two songs with the user-configured third-party Suno API service. '
        'This operation may incur provider charges and can take several minutes. '
        'Completed MP3 files are sent directly to the current conversation as playable-by-device attachments. '
        'Use this only when the user asks for music. Never retry automatically after timeout, cancellation or failure; the provider may have charged.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'prompt': {'type': 'string', 'minLength': 1, 'maxLength': 1000},
        'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
        'instrumental': {'type': 'boolean'},
      },
      'required': ['prompt', 'title', 'instrumental'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final client = MusicGenerationClient();
    _client = client;
    try {
      final result = await run(call.arguments, client);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: result,
      );
    } finally {
      client.close();
      _client = null;
    }
  }

  @override
  Future<void> cancel() async => _client?.cancel();
}
