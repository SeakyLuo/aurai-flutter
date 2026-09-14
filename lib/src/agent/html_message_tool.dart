import '../domain/tool_models.dart';

class HtmlMessageTool implements AgentTool, RuntimeCapabilityAgentTool {
  HtmlMessageTool(this.send);
  final Future<Map<String, Object?>> Function(Map<String, Object?>) send;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'sendHtmlMessage',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        'Send one HTML message card as yourself to the current private or group conversation. '
        'Supply a short title and self-contained HTML body fragment with inline CSS and JavaScript. For inline rendering use compact responsive content without a page-sized wrapper or min-height:100vh. Avoid repeated title bars and developer diagnostics. Inherit the host font and use CSS variables --aurai-text, --aurai-muted, --aurai-field, --aurai-border, --aurai-accent for light/dark themes; custom layouts and Canvas remain supported. In chat, height is a maximum and content is measured automatically; fullscreen uses the page viewport. '
        'displayMode selects inline (chat interaction only), hybrid (chat interaction with optional fullscreen), or standalone (static launch card; runs only when opened). Use hybrid for quick chat games, standalone for full applications. In fullscreen the host sets html[data-aurai-display=fullscreen]; adapt the layout to the available viewport, removing outer card decoration and using flexible content height. In inline mode keep content compact. The host supplies sender/menu and fullscreen back controls. '
        'Use ordinary DOM events for local interaction. External network requests, remote scripts, '
        'iframes and native device operations are unavailable; embed images as data URLs. '
        'The host pauses offscreen/background content and retains a bounded cache. Fullscreen transitions reuse the live page. Eviction or app restart recreates it. When stateful is true, read AuraiHTML.state on startup and await AuraiHTML.saveState(JSON-compatible value) after meaningful changes (max 64 KB); handle save rejection. This is local message state, not AI memory. Listen on document for aurai:pause, aurai:resume and aurai:displaychange; decide whether paused time counts toward your game timer. stateful false disables custom persistent state. '
        'The host restores ordinary input/textarea/select values and dispatches aurai:restore on document. Recompute local read-only outputs on that event when needed; do not replay actions. Do not use AuraiGame or '
        'claim buttons send messages, write memory, notify AI or perform device operations. '
        'Do not send HTML as an ordinary Markdown code block when an interactive card is requested. '
        'width null fits the message; height is 180–640 logical pixels. '
        'No human handoff is needed merely to deliver a card: userAction must be JSON null.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
        'html': {
          'type': 'string',
          'minLength': 1,
          'description': 'HTML body fragment, up to 256 KB UTF-8.',
        },
        'width': {
          'type': ['integer', 'null'],
          'minimum': 180,
          'maximum': 600,
        },
        'stateful': {
          'type': 'boolean',
          'default': false,
          'description':
              'Enable persistent local progress via AuraiHTML.state and saveState. Default false; use true for games/forms that must survive eviction or restart.',
        },
        'displayMode': {
          'type': 'string',
          'enum': ['inline', 'hybrid', 'standalone'],
          'description':
              'inline: chat only; hybrid: chat and fullscreen; standalone: tap a static title/preview card to run fullscreen.',
        },
        'height': {'type': 'integer', 'minimum': 180, 'maximum': 640},
      },
      'required': ['title', 'html', 'width', 'height', 'displayMode'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final args = call.arguments;
      if (args.containsKey('stateful') && args['stateful'] is! bool) {
        throw ArgumentError('stateful 必须是布尔值 true 或 false');
      }
      if (!['inline', 'hybrid', 'standalone'].contains(args['displayMode'])) {
        throw ArgumentError('displayMode 必须为 inline、hybrid 或 standalone');
      }
      if (args['title'] is! String ||
          args['html'] is! String ||
          args['height'] is! int ||
          (args['width'] != null && args['width'] is! int)) {
        throw ArgumentError(
          '请提供 title、html 字符串和 height 整数；width 使用整数或 JSON null',
        );
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: await send(args),
      );
    } on ArgumentError catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.message},
      );
    } on StateError catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.message},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
