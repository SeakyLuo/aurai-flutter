import '../domain/tool_models.dart';
import '../features/chat/conversation.dart';
import '../storage/development_projects.dart';
import '../skills/skill_icon_names.dart';
import '../features/chat/avatar_background.dart';

class ProjectTool
    implements AgentTool, RuntimeCapabilityAgentTool, PreflightAgentTool {
  ProjectTool({
    required this.operation,
    required this.projects,
    required this.conversation,
    required this.createManaged,
    required this.setConversationProject,
    required this.changed,
  });

  static const operations = [
    'list',
    'create',
    'rename',
    'setIcon',
    'setPinned',
    'setMemoryMode',
    'setCurrentConversation',
  ];

  final String operation;
  final DevelopmentProjects projects;
  final Conversation conversation;
  final Future<DevelopmentProject> Function(
    String name,
    String icon,
    String iconColor,
  )
  createManaged;
  final Future<void> Function(Conversation conversation, String? projectId)
  setConversationProject;
  final void Function() changed;
  String _projectName = '';

  String get _toolName => switch (operation) {
    'list' => 'listProjects',
    'create' => 'createProject',
    'rename' => 'renameProject',
    'setIcon' => 'setProjectIcon',
    'setPinned' => 'setProjectPinned',
    'setMemoryMode' => 'setProjectMemoryMode',
    _ => 'setCurrentConversationProject',
  };

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    if (operation == 'list' || operation == 'create') return null;
    final projectId = call.arguments['projectId'] as String?;
    if (projectId == null && operation == 'setCurrentConversation') {
      _projectName = '';
      return null;
    }
    final project = await projects.read(projectId!);
    _projectName = project.name;
    return null;
  }

  @override
  ToolDefinition get definition => ToolDefinition(
    name: _toolName,
    capabilityId: 'local.app',
    safety: operation == 'list' ? ToolSafety.readOnly : ToolSafety.sensitive,
    singleUseConfirmation: operation != 'list',
    confirmationDescriptionBuilder: (arguments) => switch (operation) {
      'create' => '是否在 Aurai 中创建项目“${arguments['name']}”？',
      'rename' => '是否将项目“$_projectName”重命名为“${arguments['name']}”？',
      'setIcon' => '是否更改项目“$_projectName”的图标？',
      'setPinned' =>
        arguments['pinned'] == true
            ? '是否置顶项目“$_projectName”？'
            : '是否取消置顶项目“$_projectName”？',
      'setMemoryMode' =>
        arguments['memoryMode'] == 'projectOnly'
            ? '是否将项目“$_projectName”设为仅使用项目记忆？'
            : '是否将项目“$_projectName”设为使用默认记忆？',
      _ =>
        arguments['projectId'] == null
            ? '是否将当前会话移出项目？'
            : '是否将当前会话移入项目“$_projectName”？',
    },
    description: switch (operation) {
      'list' =>
        'List active Aurai development projects. Returns internal project references for later project tool calls; never ask the user to type or copy an ID.',
      'create' =>
        'Create a development project in Aurai managed storage. Use this only when the user wants a new project stored inside Aurai. To bind a phone folder, the user must use the project screen so Android can grant folder access.',
      'rename' =>
        'Rename an existing development project. Read listProjects first and use its internal project reference.',
      'setIcon' =>
        'Change an existing project icon using the same icon library as Aurai tools. Read listProjects first and use its internal project reference.',
      'setPinned' =>
        'Pin or unpin an existing project. Read listProjects first and use its internal project reference.',
      'setMemoryMode' =>
        'Set whether AIs in a project may also read their own private memories. Every AI in the project always reads and writes the same project shared memory.',
      _ =>
        'Move the current conversation (private or group chat) into an existing project, or remove it from its project with null. Only the group owner or an administrator may change a group chat project. User approval does not override this role requirement. Read listProjects first when assigning a project.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (operation == 'create' || operation == 'rename')
          'name': {
            'type': 'string',
            'minLength': 1,
            'maxLength': projectNameMaxLength,
          },
        if (operation == 'create' || operation == 'setIcon')
          'icon': {'type': 'string', 'enum': skillIconChoices.keys.toList()},
        if (operation == 'create' || operation == 'setIcon')
          'iconColor': {
            'type': 'string',
            'enum': [
              'ink',
              'default',
              ...avatarColors.keys.where((key) => key != 'ink'),
            ],
          },
        if (operation == 'rename' ||
            operation == 'setIcon' ||
            operation == 'setPinned' ||
            operation == 'setMemoryMode')
          'projectId': {'type': 'string'},
        if (operation == 'setPinned') 'pinned': {'type': 'boolean'},
        if (operation == 'setMemoryMode')
          'memoryMode': {
            'type': 'string',
            'enum': ['shared', 'projectOnly'],
          },
        if (operation == 'setCurrentConversation')
          'projectId': {
            'type': ['string', 'null'],
            'description':
                'Project reference returned by listProjects, or null to remove the current conversation from its project.',
          },
      },
      'required': [
        if (operation == 'create') ...['name', 'icon', 'iconColor'],
        if (operation == 'rename') ...['projectId', 'name'],
        if (operation == 'setIcon') ...['projectId', 'icon', 'iconColor'],
        if (operation == 'setPinned') ...['projectId', 'pinned'],
        if (operation == 'setMemoryMode') ...['projectId', 'memoryMode'],
        if (operation == 'setCurrentConversation') 'projectId',
      ],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final Map<String, Object?> output;
      if (operation == 'list') {
        output = {
          'projects': [
            for (final project in await projects.list())
              {
                'projectId': project.id,
                'name': project.name,
                'icon': project.icon,
                'iconColor': project.iconColor,
                'pinned': project.pinned,
                'memoryMode': project.memoryMode.name,
                'current': project.id == conversation.projectId,
              },
          ],
        };
      } else if (operation == 'create') {
        final project = await createManaged(
          (call.arguments['name'] as String).trim(),
          call.arguments['icon'] as String,
          call.arguments['iconColor'] as String,
        );
        output = {
          'projectId': project.id,
          'name': project.name,
          'created': true,
        };
      } else if (operation == 'rename') {
        final name = (call.arguments['name'] as String).trim();
        await projects.rename(call.arguments['projectId'] as String, name);
        changed();
        output = {'renamed': true, 'name': name};
      } else if (operation == 'setIcon') {
        final icon = call.arguments['icon'] as String;
        final iconColor = call.arguments['iconColor'] as String;
        await projects.setIcon(
          call.arguments['projectId'] as String,
          icon,
          iconColor,
        );
        changed();
        output = {'updated': true, 'icon': icon, 'iconColor': iconColor};
      } else if (operation == 'setPinned') {
        final pinned = call.arguments['pinned'] as bool;
        await projects.setPinned(call.arguments['projectId'] as String, pinned);
        changed();
        output = {'updated': true, 'pinned': pinned};
      } else if (operation == 'setMemoryMode') {
        final mode = ProjectMemoryMode.values.byName(
          call.arguments['memoryMode'] as String,
        );
        await projects.setMemoryMode(
          call.arguments['projectId'] as String,
          mode,
        );
        changed();
        output = {'updated': true, 'memoryMode': mode.name};
      } else {
        final projectId = call.arguments['projectId'] as String?;
        await setConversationProject(conversation, projectId);
        output = {
          'updated': true,
          'projectId': projectId,
          if (projectId != null) 'projectName': _projectName,
        };
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
