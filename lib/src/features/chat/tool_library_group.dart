import '../../domain/tool_models.dart';

enum ToolLibraryGroup {
  conversations('会话与朋友'),
  groups('群聊管理'),
  interactions('交互消息'),
  miniapps('小程序'),
  tasks('任务与执行'),
  schedules('定时任务'),
  memory('记忆'),
  skills('技能'),
  web('网页与搜索'),
  creation('图片与音乐创作'),
  documents('文件与文档'),
  projects('项目与版本管理'),
  models('模型账户'),
  screen('屏幕与交互'),
  apps('应用与系统设置'),
  commands('脚本与命令'),
  network('网络'),
  notifications('通知'),
  other('其他工具');

  const ToolLibraryGroup(this.label);
  final String label;

  static ToolLibraryGroup forTool(ToolDefinition tool) {
    // 同一能力包含不同用途时，按具体操作分组，不改变工具的授权能力。
    final operationGroup = switch (tool.name) {
      'runSkill' => skills,
      'compactContext' || 'hideThinking' => tasks,
      'sendQuickReply' ||
      'sendInteractiveMessage' ||
      'readInteractiveMessage' ||
      'updateInteractiveMessage' ||
      'clickInteractiveMessage' ||
      'retryInteractiveCallback' => interactions,
      'createConversation' ||
      'renameConversation' ||
      'setConversationPinned' ||
      'setConversationArchived' ||
      'deleteConversation' ||
      'sendConversationMessage' ||
      'locateMessage' ||
      'forwardMessage' => conversations,
      'listProjects' ||
      'createProject' ||
      'renameProject' ||
      'setProjectIcon' ||
      'setProjectPinned' ||
      'setCurrentConversationProject' => projects,
      'getDeviceExtensions' => commands,
      'getModelConfiguration' ||
      'openModelConfiguration' ||
      'listModelProviders' ||
      'configureModelProvider' ||
      'configureProviderBalance' ||
      'configureProviderIcon' ||
      'requestModelProviderKey' ||
      'listProviderModels' ||
      'checkModelProvider' => models,
      _ => null,
    };
    if (operationGroup != null) return operationGroup;

    return switch (tool.capabilityId) {
      'local.history' || 'local.ai_contacts' => conversations,
      'local.group_chats' => groups,
      'user.question' || 'interactiveDecision' => interactions,
      'local.messages' => miniapps,
      'task.manage' ||
      'runtime.subagent' ||
      'runtime.tool_search' ||
      'local.diagnostics' => tasks,
      'android.scheduled_tasks' => schedules,
      'memory.manage' => memory,
      'skills' => skills,
      'web.read' || 'web.images' => web,
      'images.generate' || 'music.generate' => creation,
      'android.documents' || 'local.attachments' => documents,
      'local.git' => projects,
      'model.settings' || 'model.balance' || 'model.topUp' => models,
      'android.observe' ||
      'android.vision' ||
      'android.accessibility' ||
      'android.permissions' => screen,
      'android.apps' ||
      'android.intents' ||
      'android.settings' ||
      'local.app' => apps,
      'android.runtime' ||
      'android.shell.app_uid' ||
      'android.execution.shizuku' => commands,
      'android.network' || 'android.network.capture' => network,
      'android.notifications.observe' ||
      'android.notifications.send' => notifications,
      _ => other,
    };
  }
}
