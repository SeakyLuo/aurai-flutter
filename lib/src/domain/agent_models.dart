import 'tool_customization.dart';
import 'tool_models.dart';
import '../html_games/html_game.dart';
import 'interactive_message.dart';
import 'message_quote.dart';
import 'message_file.dart';
import 'message_sender.dart';
import 'message_image.dart';
import 'message_quick_reply.dart';
import 'miniapp_share.dart';

enum AgentMessageRole { user, assistant }

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.images = const [],
    this.files = const [],
    this.taskSummary,
    this.runId,
    this.modelTurnId,
    this.responseInput,
    this.sender,
    this.isSystem = false,
    this.isFailure = false,
    this.isGroupMessage = false,
    this.markdown = false,
    this.isReasoning = false,
    this.isRichReply = false,
    this.quote,
    InteractiveMessage? interactive,
    List<String>? audience,
    List<String>? excludedAudience,
    this.htmlGame,
    this.miniappShare,
    this.quickReplyToId,
    this.quickReplyKey,
    this.quickReplies = const [],
  }) : _interactive = interactive,
       _audience = audience,
       _excludedAudience = excludedAudience;

  AgentMessage withSender(
    MessageSender? value, {
    InteractiveMessage? interactive,
    MessageQuote? quote,
  }) => AgentMessage(
    id: id,
    role: role,
    senderId: senderId,
    sender: value,
    text: interactive == null
        ? text
        : '${interactive.title}\n${interactive.body}',
    interactive: interactive ?? messageMetadata,
    htmlGame: htmlGame,
    miniappShare: miniappShare,
    createdAt: createdAt,
    images: images,
    files: files,
    taskSummary: taskSummary,
    runId: runId,
    modelTurnId: modelTurnId,
    responseInput: responseInput,
    isSystem: isSystem,
    isFailure: isFailure,
    isGroupMessage: isGroupMessage,
    markdown: markdown,
    isReasoning: isReasoning,
    isRichReply: isRichReply,
    quote: quote ?? this.quote,
    quickReplyToId: quickReplyToId,
    quickReplyKey: quickReplyKey,
    quickReplies: quickReplies,
  );

  AgentMessage withQuickReplies(List<MessageQuickReply> value) => AgentMessage(
    id: id,
    role: role,
    senderId: senderId,
    sender: sender,
    text: text,
    interactive: messageMetadata,
    htmlGame: htmlGame,
    miniappShare: miniappShare,
    createdAt: createdAt,
    images: images,
    files: files,
    taskSummary: taskSummary,
    runId: runId,
    modelTurnId: modelTurnId,
    responseInput: responseInput,
    isSystem: isSystem,
    isFailure: isFailure,
    isGroupMessage: isGroupMessage,
    markdown: markdown,
    isReasoning: isReasoning,
    isRichReply: isRichReply,
    quote: quote,
    quickReplyToId: quickReplyToId,
    quickReplyKey: quickReplyKey,
    quickReplies: value,
  );

  AgentMessage withText(String value) => AgentMessage(
    id: id,
    role: role,
    senderId: senderId,
    sender: sender,
    text: value,
    createdAt: createdAt,
    images: images,
    files: files,
    taskSummary: taskSummary,
    runId: runId,
    modelTurnId: modelTurnId,
    responseInput: responseInput,
    isSystem: isSystem,
    isFailure: isFailure,
    isGroupMessage: isGroupMessage,
    markdown: markdown,
    isReasoning: isReasoning,
    isRichReply: isRichReply,
    quote: quote,
    interactive: interactive != null && interactive!.title == text
        ? InteractiveMessage.fromJson({
            ...interactive!.toJson(includeParticipants: true),
            'title': value,
          })
        : messageMetadata,
    htmlGame: htmlGame,
    miniappShare: miniappShare,
    quickReplyToId: quickReplyToId,
    quickReplyKey: quickReplyKey,
    quickReplies: quickReplies,
  );

  final HtmlGameCard? htmlGame;
  final MiniappShare? miniappShare;
  final InteractiveMessage? _interactive;
  final List<String>? _audience;
  List<String>? get audience =>
      _audience ??
      (_interactive?.participation['audience'] as List?)?.cast<String>();
  final List<String>? _excludedAudience;
  List<String>? get excludedAudience =>
      _excludedAudience ??
      (_interactive?.participation['excludedAudience'] as List?)
          ?.cast<String>();
  bool get hasRestrictedAudience =>
      audience != null || excludedAudience != null;
  String get visibilityLabel => excludedAudience != null
      ? '部分不可见'
      : audience != null
      ? '部分可见'
      : '全部可见';
  bool canView(String viewer) =>
      (audience == null || audience!.contains(viewer)) &&
      !(excludedAudience?.contains(viewer) ?? false);
  InteractiveMessage? get interactive =>
      _interactive?.participation['presentation'] == 'message'
      ? null
      : _interactive;
  InteractiveMessage? get messageMetadata =>
      _interactive ??
      (_audience == null && _excludedAudience == null
          ? null
          : InteractiveMessage(
              revision: 1,
              title: '',
              body: '',
              buttons: const [],
              participation: {
                if (_audience != null) 'audience': _audience,
                if (_excludedAudience != null)
                  'excludedAudience': _excludedAudience,
                'presentation': 'message',
              },
            ));
  final MessageQuote? quote;
  final bool isSystem;
  final bool isFailure;
  final bool isGroupMessage;
  final bool markdown;
  final bool isReasoning;
  // Derived in a page-wide read, including runs whose cards are off-page.
  final bool isRichReply;
  final String id;
  final AgentMessageRole role;
  final String senderId;
  final MessageSender? sender;
  final String text;
  final DateTime createdAt;
  final List<MessageImage> images;
  final List<MessageFile> files;
  final AgentTaskSummary? taskSummary;
  final String? runId;
  final String? modelTurnId;
  final List<Map<String, Object?>>? responseInput;
  final String? quickReplyToId;
  final String? quickReplyKey;
  final List<MessageQuickReply> quickReplies;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'role': role.name,
    'senderId': senderId,
    if (messageMetadata != null) 'interactive': messageMetadata!.toJson(),
    if (htmlGame != null) 'htmlGameTitle': htmlGame!.title,
    if (miniappShare != null) 'miniappShare': miniappShare!.toJson(),
    if (quote != null) 'quote': quote!.toJson(),
    if (isSystem) 'isSystem': true,
    if (isFailure) 'isFailure': true,
    if (isGroupMessage) 'isGroupMessage': true,
    if (markdown) 'markdown': true,
    if (isReasoning) 'isReasoning': true,
    if (quickReplyToId != null) 'quickReplyToId': quickReplyToId,
    if (quickReplyKey != null) 'quickReplyKey': quickReplyKey,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'images': images.map((image) => image.toJson()).toList(),
    'files': files.map((file) => file.toJson()).toList(),
    if (taskSummary != null) 'taskSummary': taskSummary!.toJson(),
  };

  factory AgentMessage.fromJson(
    Map<String, Object?> json, {
    required String imageDirectory,
  }) => AgentMessage(
    id: json['id']! as String,
    miniappShare: json['miniappShare'] == null
        ? null
        : MiniappShare.fromJson(
            (json['miniappShare'] as Map).cast<String, Object?>(),
            imageDirectory,
          ),
    htmlGame: json['htmlGameTitle'] == null
        ? null
        : HtmlGameCard(title: json['htmlGameTitle'] as String),
    interactive: json['interactive'] == null
        ? null
        : InteractiveMessage.fromJson(
            Map<String, Object?>.from(json['interactive'] as Map),
          ),
    isSystem: json['isSystem'] == true,
    isFailure: json['isFailure'] == true,
    isGroupMessage: json['isGroupMessage'] == true,
    markdown: json['markdown'] == true,
    isReasoning: json['isReasoning'] == true,
    quickReplyToId: json['quickReplyToId'] as String?,
    quickReplyKey: json['quickReplyKey'] as String?,
    quote: json['quote'] == null
        ? null
        : MessageQuote.fromJson((json['quote'] as Map).cast<String, Object?>()),
    role: AgentMessageRole.values.byName(json['role']! as String),
    // JSON conversations saved before sender identities only contain a role.
    senderId:
        json['senderId'] as String? ??
        (json['role'] == 'user'
            ? MessageSender.localUser.id
            : MessageSender.aurai.id),
    text: json['text']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    taskSummary: json['taskSummary'] == null
        ? null
        : AgentTaskSummary.fromJson(
            (json['taskSummary']! as Map).cast<String, Object?>(),
          ),
    files: (json['files'] as List? ?? const [])
        .map(
          (file) => MessageFile.fromJson(
            (file as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        )
        .toList(),
    images: (json['images'] as List? ?? const [])
        .map(
          (image) => MessageImage.fromJson(
            (image as Map).cast<String, Object?>(),
            imageDirectory,
          ),
        )
        .toList(),
  );
}

enum AgentStepStatus {
  running,
  completed,
  failed,
  cancelled;

  static AgentStepStatus fromResult(ToolResult result) {
    if (result.status == ToolResultStatus.success &&
        result.output['pending'] == true &&
        result.output['newQuestionShown'] != false) {
      return running;
    }
    return switch (result.status) {
      ToolResultStatus.success => completed,
      ToolResultStatus.cancelled => cancelled,
      ToolResultStatus.denied || ToolResultStatus.error => failed,
    };
  }
}

class AgentStep {
  const AgentStep({
    this.callId,
    required this.toolName,
    required this.title,
    required this.status,
    this.detail,
    this.requestJson,
    this.resultJson,
    this.startedAt,
    this.finishedAt,
  });

  final String toolName;
  final String? callId;
  final String title;
  final AgentStepStatus status;
  final String? detail;
  final String? requestJson;
  final String? resultJson;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  AgentStep copyWith({
    AgentStepStatus? status,
    String? detail,
    String? resultJson,
  }) => AgentStep(
    callId: callId,
    toolName: toolName,
    title: title,
    status: status ?? this.status,
    detail: detail ?? this.detail,
    requestJson: requestJson,
    resultJson: resultJson ?? this.resultJson,
    startedAt: startedAt,
    finishedAt:
        finishedAt ??
        (startedAt != null &&
                status != null &&
                status != AgentStepStatus.running
            ? DateTime.now()
            : null),
  );
}

class AgentTaskSummary {
  const AgentTaskSummary({
    required this.elapsedMilliseconds,
    this.isTask = true,
    this.stopped = false,
    required this.intermediateMessageIds,
    required this.activities,
    this.gitChanges,
  });

  final int elapsedMilliseconds;
  final bool isTask;
  final bool stopped;
  final List<String> intermediateMessageIds;
  final List<AgentTaskActivity> activities;
  final ProjectGitTaskChanges? gitChanges;

  Map<String, Object?> toJson() => {
    'elapsedMilliseconds': elapsedMilliseconds,
    'isTask': isTask,
    'stopped': stopped,
    'intermediateMessageIds': intermediateMessageIds,
    'activities': activities.map((activity) => activity.toJson()).toList(),
    if (gitChanges != null) 'gitChanges': gitChanges!.toJson(),
  };

  factory AgentTaskSummary.fromJson(
    Map<String, Object?> json,
  ) => AgentTaskSummary(
    elapsedMilliseconds: json['elapsedMilliseconds']! as int,
    isTask: json['isTask'] != false,
    stopped: json['stopped'] == true,
    intermediateMessageIds: (json['intermediateMessageIds']! as List)
        .cast<String>(),
    activities: (json['activities']! as List)
        .map(
          (item) =>
              AgentTaskActivity.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(),
    gitChanges: json['gitChanges'] == null
        ? null
        : ProjectGitTaskChanges.fromJson(
            (json['gitChanges'] as Map).cast<String, Object?>(),
          ),
  );
}

class ProjectGitTaskChanges {
  const ProjectGitTaskChanges({
    required this.workspaceId,
    required this.taskId,
    required this.fileCount,
    required this.addedLines,
    required this.removedLines,
    this.directoryName,
    this.directories = const [],
    required this.previewFiles,
  });

  final String workspaceId;
  final String taskId;
  final int fileCount;
  final int addedLines;
  final int removedLines;
  final String? directoryName;
  final List<ProjectGitTaskChanges> directories;
  final List<ProjectGitTaskFileChange> previewFiles;

  Map<String, Object?> toJson() => {
    'workspaceId': workspaceId,
    'taskId': taskId,
    'fileCount': fileCount,
    'addedLines': addedLines,
    'removedLines': removedLines,
    'directoryName': directoryName,
    'directories': directories.map((item) => item.toJson()).toList(),
    'previewFiles': previewFiles.map((item) => item.toJson()).toList(),
  };

  factory ProjectGitTaskChanges.fromJson(
    Map<String, Object?> json,
  ) => ProjectGitTaskChanges(
    workspaceId: json['workspaceId']! as String,
    taskId: json['taskId']! as String,
    fileCount: json['fileCount']! as int,
    addedLines: json['addedLines']! as int,
    removedLines: json['removedLines']! as int,
    directoryName: json['directoryName'] as String?,
    directories: (json['directories'] as List? ?? const [])
        .cast<Map>()
        .map(
          (item) =>
              ProjectGitTaskChanges.fromJson(item.cast<String, Object?>()),
        )
        .toList(),
    previewFiles: (json['previewFiles']! as List)
        .cast<Map>()
        .map(
          (item) =>
              ProjectGitTaskFileChange.fromJson(item.cast<String, Object?>()),
        )
        .toList(),
  );
}

class ProjectGitTaskFileChange {
  const ProjectGitTaskFileChange({
    required this.path,
    required this.addedLines,
    required this.removedLines,
    this.oldPath,
  });

  final String path;
  final String? oldPath;
  final int addedLines;
  final int removedLines;

  Map<String, Object?> toJson() => {
    'path': path,
    'oldPath': oldPath,
    'addedLines': addedLines,
    'removedLines': removedLines,
  };

  factory ProjectGitTaskFileChange.fromJson(Map<String, Object?> json) =>
      ProjectGitTaskFileChange(
        path: json['path']! as String,
        oldPath: json['oldPath'] as String?,
        addedLines: json['addedLines']! as int,
        removedLines: json['removedLines']! as int,
      );
}

class AgentTaskActivity {
  const AgentTaskActivity({
    required this.text,
    this.isReasoning = false,
    this.messageId,
    this.status,
    this.toolName,
    this.requestJson,
    this.resultJson,
    this.startedAt,
    this.finishedAt,
  });

  final String text;
  final bool isReasoning;
  final String? messageId;
  final String? toolName;
  final AgentStepStatus? status;
  final String? requestJson;
  final String? resultJson;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  Map<String, Object?> toJson() => {
    'text': text,
    if (isReasoning) 'isReasoning': true,
    if (messageId != null) 'messageId': messageId,
    if (toolName != null) 'toolName': toolName,
    'status': status?.name,
    if (requestJson != null) 'requestJson': requestJson,
    if (resultJson != null) 'resultJson': resultJson,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
  };

  factory AgentTaskActivity.fromJson(Map<String, Object?> json) {
    final status = json['status'] as String?;
    return AgentTaskActivity(
      text: json['text']! as String,
      isReasoning: json['isReasoning'] == true,
      messageId: json['messageId'] as String?,
      toolName: json['toolName'] as String?,
      status: status == null ? null : AgentStepStatus.values.byName(status),
      requestJson: json['requestJson'] as String?,
      resultJson: json['resultJson'] as String?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
    );
  }
}

class AgentRunResult {
  const AgentRunResult({required this.answer, required this.steps});

  final String answer;
  final List<AgentStep> steps;
}

typedef AgentStepListener = void Function(List<AgentStep> steps);

String newMessageId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String toolTitle(String name) =>
    ToolCustomizations.values[name]?.title ?? _defaultToolTitle(name);

String _defaultToolTitle(String name) => switch (name) {
  'runSubagent' => '子代理',
  'runTask' => '任务',
  'createGoal' => '建立目标',
  'clearGoal' => '清除目标',
  'readGroupPersonalDetails' => '读取群个人资料',
  'updateGroupPersonalDetails' => '更新群个人资料',
  'createTaskList' => '建立执行计划',
  'getGoal' => '查看目标',
  'getTaskList' => '查看执行计划',
  'updateGoal' => '更新目标状态',
  'updateTaskList' => '更新执行计划',
  'readMyProfile' => '读取自己的资料',
  'updateMyProfile' => '更新自己的资料',
  'listHtmlApps' => '查找小程序',
  'readHtmlAppData' => '读取小程序数据',
  'writeHtmlAppData' => '保存小程序数据',
  'sendHtmlMessage' => '发送 HTML 消息',
  'readHtmlMessage' => '读取 HTML 消息',
  'readHtmlProgram' => '读取小程序状态',
  'readHtmlData' => '读取 HTML 数据',
  'updateHtmlData' => '更新 HTML 数据',
  'submitHtmlProgramEvent' => '提交小程序行动',
  'readHtmlApp' => '读取小程序',
  'readHtmlAppTeam' => '查看开发团队',
  'requestHtmlAppEdit' => '申请修改小程序',
  'manageHtmlAppTeam' => '管理开发团队',
  'listHtmlAppEditRequests' => '查看修改申请',
  'mergeProjectBranch' => '合并项目分支',
  'checkoutProjectBranch' => '切换项目分支',
  'updateHtmlApp' => '修改小程序',
  'updateHtmlMessage' => '更新 HTML 消息',
  'sendInteractiveMessage' => '发送交互消息',
  'findContacts' => '查找联系人',
  'listFriends' => '查看好友',
  'addFriend' => '添加好友',
  'readExecutionLogs' => '读取执行日志',
  'clickInteractiveMessage' => '参与交互消息',
  'submitInteractiveChoice' => '提交选择',
  'finishCurrentAction' => '完成当前行动',
  'finishCurrentSpeech' => '结束当前发言',
  'readInteractiveMessage' => '读取交互消息',
  'retryInteractiveCallback' => '重试交互处理',
  'updateInteractiveMessage' => '更新交互消息',
  'createConversation' => '新建会话',
  'renameConversation' => '重命名会话',
  'setConversationPinned' => '调整会话置顶',
  'setConversationArchived' => '调整会话归档',
  'deleteConversation' => '删除会话',
  'listHtmlAppPublications' => '查找可发布小程序',
  'readHtmlAppPublication' => '查看小程序发布状态',
  'publishHtmlApp' => '发布小程序',
  'updateHtmlAppPublication' => '发布小程序更新',
  'setHtmlAppIcon' => '设置小程序图标',
  'withdrawHtmlApp' => '撤下小程序',
  'sendConversationMessage' => '发送私聊消息',
  'openAppPage' => '打开应用页面',
  'locateMessage' => '定位原消息',
  'forwardMessage' => '转发消息',
  'getModelConfiguration' => '检查模型配置',
  'listModelProviders' => '查看模型供应商',
  'configureModelProvider' => '配置模型供应商',
  'requestModelProviderKey' => '填写供应商密钥',
  'listProviderModels' => '获取供应商模型',
  'checkModelProvider' => '检查模型连接',
  'openModelConfiguration' => '打开模型设置',
  'sendGroupMessage' => '发送群消息',
  'wakeGroupMember' => '唤醒群成员',
  'setGroupMemberMute' => '设置成员禁言',
  'pauseGroupAutoReply' => '暂停成员自动接话',
  'resumeGroupAutoReply' => '恢复成员自动接话',
  'sleepGroupChat' => '稍后查看群聊',
  'hideThinking' => '隐藏思考',
  'compactContext' => '压缩上下文',
  'starMessage' => '收藏消息',
  'unstarMessage' => '取消收藏消息',
  'listStarredMessages' => '查看收藏消息',
  'sendQuickReply' => '发送快捷回复',
  'recallMessage' => '撤回消息',
  'listGroupChats' => '查询群聊',
  'readMessage' => '读取历史消息',
  'readMessageAttachment' => '读取历史附件',
  'readGroupMessages' => '读取群历史消息',
  'readGroupChat' => '读取群聊',
  'readGroupPinnedMessage' => '读取置顶消息',
  'pinGroupMessage' => '置顶群消息',
  'unpinGroupMessage' => '取消群消息置顶',
  'listGroupFavorites' => '读取群标记',
  'addGroupFavorite' => '添加群标记',
  'removeGroupFavorite' => '取消群标记',
  'readGroupAnnouncement' => '读取群公告',
  'updateGroupAnnouncement' => '更新群公告',
  'createGroupChat' => '创建群聊',
  'renameGroupChat' => '重命名群聊',
  'updateGroupChatMembers' => '调整群成员',
  'listAiContacts' => '查询联系人',
  'readAiContact' => '读取联系人',
  'createAiContact' => '创建联系人',
  'updateAiContact' => '修改联系人',
  'deleteAiContact' => '归档联系人',
  'restoreAiContact' => '恢复联系人',
  'readAttachment' => '读取附件',
  'searchImages' => '搜索图片',
  'generateImage' => '生成图片',
  'generateMusic' => '生成音乐',
  'searchWeb' => '搜索网页',
  'setSourceDates' => '补充来源时间',
  'searchTools' => '搜索工具',
  'loadTools' => '加载工具',
  'inspectLocalDatabase' => '查看本地记录结构',
  'queryLocalDatabase' => '查询本地记录',
  'clickUiElement' => '点击界面元素',
  'inputUiText' => '输入文字',
  'scrollUiForward' => '向前滚动界面',
  'scrollUiBackward' => '向后滚动界面',
  'goBack' => '返回上一页',
  'goHome' => '返回主屏幕',
  'readWebPage' => '读取网页',
  'listMemories' => '查询记忆',
  'readMemory' => '读取记忆',
  'createMemory' => '新增记忆',
  'updateMemory' => '修改记忆',
  'deleteMemory' => '删除记忆',
  'prepareMemoryChanges' => '整理记忆建议',
  'applyMemoryChanges' => '应用记忆调整',
  'readRequestAdapters' => '读取请求转换',
  'previewRequestAdapter' => '试运行请求转换',
  'saveRequestAdapter' => '保存请求转换',
  'readDefaultModels' => '读取默认模型配置',
  'updateDefaultModel' => '修改默认模型',
  'getModelBalance' => '查询模型账户余额',
  'openModelTopUp' => '打开官方充值页',
  'searchConversations' => '搜索历史会话',
  'searchMessages' => '搜索历史消息',
  'readLocalDatabase' => '读取本地记录',
  'getNetworkState' => '检查当前网络',
  'getNetworkEvents' => '读取网络变化记录',
  'dnsLookup' => '解析域名',
  'tlsProbe' => '检查 TLS 连接',
  'httpProbe' => '检查 HTTPS 请求',
  'getNotifications' => '读取通知观察',
  'sendNotification' => '发送通知',
  'manageSkill' => '管理技能',
  'listSkills' => '查询技能',
  'readSkill' => '读取技能',
  'createSkill' => '创建技能',
  'updateSkill' => '修改技能',
  'deleteSkill' => '删除技能',
  'installSkill' => '安装技能',
  'uninstallSkill' => '卸载技能',
  'enableSkill' => '启用技能',
  'disableSkill' => '停用技能',
  'searchSkills' => '搜索技能库',
  'runSkill' => '运行技能',
  'scheduledTask' => '管理定时任务',
  'createScheduledTask' => '创建定时任务',
  'updateScheduledTask' => '修改定时任务',
  'listScheduledTasks' => '查询定时任务',
  'pauseScheduledTask' => '暂停定时任务',
  'resumeScheduledTask' => '恢复定时任务',
  'deleteScheduledTask' => '删除定时任务',
  'inspectAndroidApi' => '查询设备接口',
  'executeAndroidScript' => '执行设备任务',
  'observeDevice' => '观察当前界面',
  'captureScreen' => '读取当前屏幕',
  'tapScreen' => '点击屏幕位置',
  'wait' => '等待状态变化',
  'waitForUi' => '等待界面变化',
  'askUser' => '询问你',
  'requestAccessibilityAccess' => '请求界面操作权限',
  'act' => '操作当前界面',
  'findApps' => '查找应用',
  'launchApp' => '打开应用',
  'startIntent' => '启动 Android 操作',
  'openSettings' => '打开系统设置',
  'getDeviceExtensions' => '查看扩展能力',
  'requestShizukuAccess' => '授权 Shizuku',
  'executeShizuku' => '执行 Shizuku 命令',
  'startNetworkCapture' => '开始记录网络连接',
  'stopNetworkCapture' => '停止记录网络连接',
  'readNetworkTraffic' => '读取网络连接',
  'clearNetworkTraffic' => '清除连接记录',
  'getDocumentFolders' => '查看授权文件夹',
  'requestDocumentFolder' => '选择文件夹',
  'listFiles' => '列出文件',
  'searchFiles' => '搜索文件',
  'listProjectTree' => '读取项目目录',
  'searchProjectText' => '搜索项目正文',
  'readDocument' => '读取文档',
  'writeTextFile' => '修改文本文件',
  'replaceText' => '修改文本内容',
  'applyTextPatch' => '应用文件补丁',
  'createFolder' => '新建文件夹',
  'renameDocument' => '重命名文件',
  'copyDocument' => '复制文件',
  'moveDocument' => '移动文件',
  'deleteDocument' => '删除文件',
  'listProjects' => '查看项目',
  'createProject' => '创建项目',
  'renameProject' => '重命名项目',
  'setProjectIcon' => '更改项目图标',
  'setProjectPinned' => '设置项目置顶',
  'setCurrentConversationProject' => '调整会话项目',
  'runProjectCommand' => '执行项目命令',
  'getProjectGitStatus' => '读取 Git 状态',
  'getProjectGitDiff' => '读取 Git 差异',
  'initializeProjectGit' => '初始化 Git 仓库',
  'setProjectGitRemote' => '设置 Git 远端',
  'commitProjectGit' => '提交 Git 改动',
  'pullProjectGit' => '拉取 Git 更新',
  'pushProjectGit' => '推送 Git 分支',
  'readGitConfiguration' => '读取 Git 设置',
  'updateGitConfiguration' => '修改 Git 设置',
  'createTextFile' => '保存文件',
  'deliverFile' => '发送文件',
  'shareFile' => '分享文件',
  'shell' => '执行本机命令',
  _ => '执行设备检查',
};
