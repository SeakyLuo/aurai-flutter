import 'message_quote.dart';
import 'message_file.dart';
import 'message_sender.dart';
import 'message_image.dart';

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
    this.quote,
  });

  AgentMessage withSender(MessageSender? value) => AgentMessage(
    id: id,
    role: role,
    senderId: senderId,
    sender: value,
    text: text,
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
    quote: quote,
  );

  final MessageQuote? quote;
  final bool isSystem;
  final bool isFailure;
  final bool isGroupMessage;
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

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'role': role.name,
    'senderId': senderId,
    if (quote != null) 'quote': quote!.toJson(),
    if (isSystem) 'isSystem': true,
    if (isFailure) 'isFailure': true,
    if (isGroupMessage) 'isGroupMessage': true,
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
    isSystem: json['isSystem'] == true,
    isFailure: json['isFailure'] == true,
    isGroupMessage: json['isGroupMessage'] == true,
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

enum AgentStepStatus { running, completed, failed, cancelled }

class AgentStep {
  const AgentStep({
    required this.toolName,
    required this.title,
    required this.status,
    this.detail,
    this.requestJson,
    this.resultJson,
  });

  final String toolName;
  final String title;
  final AgentStepStatus status;
  final String? detail;
  final String? requestJson;
  final String? resultJson;

  AgentStep copyWith({
    AgentStepStatus? status,
    String? detail,
    String? resultJson,
  }) => AgentStep(
    toolName: toolName,
    title: title,
    status: status ?? this.status,
    detail: detail ?? this.detail,
    requestJson: requestJson,
    resultJson: resultJson ?? this.resultJson,
  );
}

class AgentTaskSummary {
  const AgentTaskSummary({
    required this.elapsedMilliseconds,
    this.stopped = false,
    required this.intermediateMessageIds,
    required this.activities,
  });

  final int elapsedMilliseconds;
  final bool stopped;
  final List<String> intermediateMessageIds;
  final List<AgentTaskActivity> activities;

  Map<String, Object?> toJson() => {
    'elapsedMilliseconds': elapsedMilliseconds,
    'stopped': stopped,
    'intermediateMessageIds': intermediateMessageIds,
    'activities': activities.map((activity) => activity.toJson()).toList(),
  };

  factory AgentTaskSummary.fromJson(
    Map<String, Object?> json,
  ) => AgentTaskSummary(
    elapsedMilliseconds: json['elapsedMilliseconds']! as int,
    stopped: json['stopped'] == true,
    intermediateMessageIds: (json['intermediateMessageIds']! as List)
        .cast<String>(),
    activities: (json['activities']! as List)
        .map(
          (item) =>
              AgentTaskActivity.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(),
  );
}

class AgentTaskActivity {
  const AgentTaskActivity({
    required this.text,
    this.messageId,
    this.status,
    this.toolName,
    this.requestJson,
    this.resultJson,
  });

  final String text;
  final String? messageId;
  final String? toolName;
  final AgentStepStatus? status;
  final String? requestJson;
  final String? resultJson;

  Map<String, Object?> toJson() => {
    'text': text,
    if (messageId != null) 'messageId': messageId,
    if (toolName != null) 'toolName': toolName,
    'status': status?.name,
    if (requestJson != null) 'requestJson': requestJson,
    if (resultJson != null) 'resultJson': resultJson,
  };

  factory AgentTaskActivity.fromJson(Map<String, Object?> json) {
    final status = json['status'] as String?;
    return AgentTaskActivity(
      text: json['text']! as String,
      messageId: json['messageId'] as String?,
      toolName: json['toolName'] as String?,
      status: status == null ? null : AgentStepStatus.values.byName(status),
      requestJson: json['requestJson'] as String?,
      resultJson: json['resultJson'] as String?,
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

String toolTitle(String name) => switch (name) {
  'readMyProfile' => '读取自己的资料',
  'updateMyProfile' => '更新自己的资料',
  'createConversation' => '新建会话',
  'renameConversation' => '重命名会话',
  'setConversationPinned' => '调整会话置顶',
  'setConversationArchived' => '调整会话归档',
  'deleteConversation' => '删除会话',
  'sendConversationMessage' => '发送会话消息',
  'openAppPage' => '打开应用页面',
  'sendGroupMessages' => '发送群消息',
  'recallMessage' => '撤回消息',
  'listGroupChats' => '查询群聊',
  'readGroupChat' => '读取群聊',
  'createGroupChat' => '创建群聊',
  'renameGroupChat' => '重命名群聊',
  'updateGroupChatMembers' => '调整群成员',
  'listAiContacts' => '查询 AI 联系人',
  'readAiContact' => '读取 AI 联系人',
  'createAiContact' => '创建 AI 联系人',
  'updateAiContact' => '修改 AI 联系人',
  'deleteAiContact' => '归档 AI 联系人',
  'restoreAiContact' => '恢复 AI 联系人',
  'readAttachment' => '读取附件',
  'searchImages' => '搜索图片',
  'searchWeb' => '搜索网页',
  'setSourceDates' => '补充来源时间',
  'searchTools' => '搜索工具',
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
  'readDocument' => '读取文档',
  'createTextFile' => '保存文件',
  'shareFile' => '分享文件',
  'shell' => '执行本机命令',
  _ => '执行设备检查',
};
