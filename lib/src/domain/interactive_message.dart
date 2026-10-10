import 'interactive_content.dart';
import 'interactive_form_presentation.dart';
export 'interactive_content.dart';
import 'interactive_button_icons.dart';
import 'anonymous_vote.dart';
import 'interactive_selection.dart';
import 'question_batch.dart';
import 'interaction_expression.dart';
import 'shared_interaction.dart';

class InteractiveMessage {
  const InteractiveMessage({
    required this.revision,
    required this.content,
    this.states = const [],
    this.participation = const {},
    this.participants = const {},
    this.interaction = const {},
    this.session = const {},
    this.snapshotView,
  });
  final Map<String, Object?> content;
  InteractiveContent get widgetTree => InteractiveContent(content);
  bool get showStatistics => widgetTree.json['showStatistics'] as bool? ?? true;
  int get buttonColumns => widgetTree.json['buttonColumns'] as int? ?? 1;

  /// Native producers use this compound widget, just as they would a Dart widget.
  factory InteractiveMessage.card({
    required int revision,
    required String title,
    required String body,
    required List<Map<String, Object?>> buttons,
    List<Map<String, Object?>> states = const [],
    Map<String, Object?> participation = const {},
    Map<String, Map<String, Object?>> participants = const {},
    Map<String, Object?> interaction = const {},
    Map<String, Object?> session = const {},
    Map<String, Object?>? snapshotView,
    bool showStatistics = true,
    int buttonColumns = 1,
  }) => InteractiveMessage(
    revision: revision,
    content: InteractiveContent.card(
      title: title,
      body: body,
      buttons: buttons,
      buttonColumns: buttonColumns,
      showStatistics: showStatistics,
    ),
    states: states,
    participation: participation,
    participants: participants,
    interaction: interaction,
    session: session,
    snapshotView: snapshotView,
  );

  /// Build the compound card from a native producer's named constructor arguments.
  static Map<String, Object?> cardDefinition(Map<String, Object?> arguments) =>
      {
        for (final entry in arguments.entries)
          if (![
            'title',
            'body',
            'buttons',
            'buttonColumns',
            'showStatistics',
          ].contains(entry.key))
            entry.key: entry.value,
        'content': InteractiveContent.card(
          title: arguments['title'] as String,
          body: arguments['body'] as String,
          buttons: (arguments['buttons'] as List)
              .map((b) => Map<String, Object?>.from(b as Map))
              .toList(),
          buttonColumns: arguments['buttonColumns'] as int? ?? 1,
          showStatistics: arguments['showStatistics'] as bool? ?? true,
        ),
        if (arguments['states'] case final List states)
          'states': [
            for (final state in states)
              cardDefinition(Map<String, Object?>.from(state as Map)),
          ],
      };
  final Map<String, Object?> interaction;
  final Map<String, Object?> session;
  final Map<String, Object?>? snapshotView;
  bool canView(String actor) =>
      (hasInteraction && participation['_creatorId'] == actor) ||
      (participation['audience'] == null ||
              (participation['audience'] as List).contains(actor)) &&
          !((participation['excludedAudience'] as List?)?.contains(actor) ??
              false);
  bool get hasRestrictedAudience =>
      participation['audience'] != null ||
      participation['excludedAudience'] != null;
  void requireViewer(String actor) {
    if (!canView(actor)) throw StateError('你无权查看这条互动消息');
  }

  void validateTransport({required bool html}) {
    if (isQuestionnaire &&
        widgetTree.json['type'] == 'InteractionCard' &&
        (html ||
            !shared ||
            buttons.length != 1 ||
            buttons.single['action'] != 'submit' ||
            (buttons.single['selection'] == null &&
                buttons.single['questions'] == null &&
                buttons.single['input'] != 'json') ||
            states.isNotEmpty ||
            (interaction['views'] as List? ?? const []).any(
              (view) => view['type'] == 'distribution',
            ))) {
      throw ArgumentError('问卷使用共享参与配置和一个选择、问题组或 DSL 表单提交按钮，不使用票数分布或状态切换');
    }
    if (buttons.any((button) => button['questions'] != null) &&
        (html ||
            !shared ||
            (!isQuestionnaire &&
                (interaction['actors'] as List?)?.length != 1) ||
            buttons.length != 1 ||
            states.isNotEmpty ||
            isVote)) {
      throw ArgumentError('问题组使用原生卡片、一个提交按钮和一位回答人，不用于投票');
    }
    if (anonymous && (!isVote || html)) {
      throw ArgumentError('匿名投票需要原生投票卡片，不能用于 HTML 输入或非投票行动');
    }
    final allButtons = [
      ...buttons,
      for (final state in states)
        ...InteractiveContent(
          Map<String, Object?>.from(state['content'] as Map),
        ).buttons,
    ];
    if (anonymous && allButtons.any((button) => button['notifyAi'] == true)) {
      throw ArgumentError(
        '匿名投票使用 participation.callbackEvents，不支持携带参与者身份的按钮回调',
      );
    }
    if (allButtons.any(
      (b) =>
          b['notifyAi'] == true &&
          (singleChoice || (b['action'] == 'submit' && b['input'] == null)),
    ))
      throw ArgumentError(
        '投票回调请通过 participation.callbackEvents 注册监听，不使用按钮结果回调',
      );
    if (!shared && allButtons.any((b) => b['selection'] != null))
      throw ArgumentError('选择列表需要 interaction 配置以保存参与者选择');
    if (!html &&
        allButtons.any((b) => b['input'] != null && b['input'] != 'json'))
      throw ArgumentError('原生表单使用 input:json');
    if (!html) {
      for (final tree in [
        widgetTree,
        for (final state in states)
          InteractiveContent(
            Map<String, Object?>.from(state['content'] as Map),
          ),
      ]) {
        if (tree.buttons.any((b) => b['input'] != null) &&
            tree.initialValues.isEmpty)
          throw ArgumentError('原生输入动作需要表单组件');
      }
    }
  }

  bool get systemPresentation => participation['presentation'] == 'system';

  /// Votes show current results by default; history is an opt-in UI feature.
  /// Questions always present the current answer without history navigation.
  bool get showHistory =>
      !isQuestion &&
      (participation['showHistory'] as bool? ?? (!isVote && !isQuestionnaire));
  bool get isQuestionnaire => participation['kind'] == 'questionnaire';
  bool get collectionPaused =>
      isQuestionnaire && participation['_collectionPaused'] == true;
  bool get isQuestion =>
      !isQuestionnaire &&
      (buttons.any((button) => button['questions'] != null) ||
          !isVote &&
              (interaction['actors'] as List?)?.length == 1 &&
              buttons.any(
                (button) =>
                    button['selection'] != null || button['questions'] != null,
              ));
  bool get shared => interaction.isNotEmpty;
  bool get hasInteraction => snapshotView != null || shared || singleChoice;
  Map<String, Object?> get interactionDefinition => shared
      ? {
          ...interaction,
          // Fixed submit buttons form a ballot even without an explicit result
          // view. Give ballots the same default results as single-choice votes.
          if (!interaction.containsKey('views') && isVote)
            'views': [
              {
                'type': 'distribution',
                'unit': '票',
                'when': {
                  'op': 'or',
                  'args': [
                    {'ref': 'submitted'},
                    {'ref': 'closed'},
                  ],
                },
              },
            ],
        }
      : {
          'allowChange': true,
          'views': [
            {
              'type': 'distribution',
              'when': {
                'op': 'or',
                'args': [
                  {'ref': 'submitted'},
                  {'ref': 'closed'},
                ],
              },
            },
          ],
        };
  SharedInteraction get engine => SharedInteraction(
    interactionDefinition,
    shared
        ? session
        : {
            'round': 1,
            'version': 0,
            'phase': closed ? 'closed' : 'collecting',
            'state': <String, Object?>{},
            'submissions': choices,
          },
  );
  int get sessionVersion => shared ? engine.version : 0;
  Map<String, Map<String, Object?>> get choices => shared
      ? engine.submissions
      : {
          for (final entry in participants.entries)
            if (entry.value['buttonId'] != null) entry.key: entry.value,
        };
  num get totalWeight => choices.values.fold<num>(
    0,
    (total, choice) => total + (choice['weight'] as num? ?? 1),
  );
  Map<String, Object?> interactionView(String actor, {String? viewer}) {
    requireViewer(viewer ?? actor);
    if (anonymous && viewer != null && viewer != actor) {
      throw StateError('匿名投票不能查看其他参与者的选择');
    }
    if (snapshotView != null) return snapshotView!;
    final ctx = engine.project(
      actor,
      closed: closed,
      choicesVisible: visible('visibility', actor: viewer ?? actor),
      summaryVisible: visible('summaryVisibility', actor: viewer ?? actor),
      distribution: summary,
    );
    final components = <Map<String, Object?>>[];
    for (final raw in interactionDefinition['views'] as List? ?? const []) {
      final view = Map<String, Object?>.from(raw as Map);
      if (evaluateInteraction(view['when'] ?? true, ctx) != true) continue;
      if (view['type'] == 'distribution') {
        if (ctx['summaryVisible'] == true)
          components.add({
            'type': 'distribution',
            'items': summary,
            'total': totalWeight,
            'selected': choices[actor],
            'unit': view['unit'] ?? (singleChoice ? '票' : '人'),
          });
      } else {
        components.add({
          'type': view['type'],
          'label': view['label'],
          'value': evaluateInteraction(view['value'], ctx),
        });
      }
    }
    return {
      for (final entry in ctx.entries)
        if (!isQuestionnaire || entry.key != 'distribution')
          entry.key: entry.value,
      if (isQuestionnaire) ...{
        'collectionPaused': collectionPaused,
        if (ctx['self'] case final Map own)
          'self': {...own, 'updatedAt': participants[actor]!['updatedAt']},
        if (ctx['submissions'] case final Map submissions)
          'submissions': {
            for (final entry in submissions.entries)
              entry.key: {
                ...entry.value as Map,
                'updatedAt': participants[entry.key]!['updatedAt'],
              },
          },
      },
      if (anonymous) 'anonymous': true,
      'components': components,
      if (ctx['summaryVisible'] == true)
        'formMetrics': interactiveFormMetrics(widgetTree, choices.values),
    };
  }

  final Map<String, Object?> participation;
  final Map<String, Map<String, Object?>> participants;
  bool get closed =>
      participation['closed'] == true ||
      (shared &&
          engine.phase == 'completed' &&
          !buttons.any((button) => button['action'] == 'nextRound') &&
          !states.any(
            (state) => InteractiveContent(
              Map<String, Object?>.from(state['content'] as Map),
            ).buttons.any((button) => button['action'] == 'nextRound'),
          ));
  bool get singleChoice => participation['selectionMode'] == 'singleChoice';
  bool get anonymous => participation['anonymous'] == true;
  bool get isVote =>
      !isQuestionnaire &&
      (singleChoice ||
          shared &&
              buttons.any(
                (button) => (button['selection'] as Map?)?['other'] != null,
              ) ||
          shared &&
              buttons
                      .where(
                        (button) =>
                            button['action'] == 'submit' &&
                            button['input'] == null &&
                            button['selection'] == null,
                      )
                      .length >
                  1 ||
          (interaction['views'] as List? ?? const []).any(
            (view) => view['type'] == 'distribution',
          ) ||
          (snapshotView?['components'] as List? ?? const []).any(
            (component) => component['type'] == 'distribution',
          ));
  bool visible(String field, {String actor = 'user:local'}) {
    if (anonymous && field == 'visibility') return false;
    if (isQuestionnaire &&
        field == 'visibility' &&
        participation['_creatorId'] == actor)
      return true;
    if (hasInteraction &&
        field == 'summaryVisibility' &&
        participation['_creatorId'] == actor)
      return true;
    if (!canView(actor)) return false;
    final allowed = participation['${field}Actors'] as List?;
    if (allowed != null && !allowed.contains(actor)) return false;
    if (field == 'visibility' &&
        (participation['visibilityExcludedActors'] as List?)?.contains(actor) ==
            true)
      return false;
    final timing = participation['${field}Timing'];
    final early = participation['${field}ImmediateActors'] as List?;
    final immediate = early?.contains(actor) == true;
    if (!immediate) {
      if (timing == 'onComplete' && !completed) return false;
      if (timing == null && shared && !engine.revealed) return false;
    }
    return switch (participation[field] ??
        (isQuestionnaire && field == 'visibility' ? 'private' : 'public')) {
      'public' => true,
      'afterClose' => immediate || completed,
      _ => false,
    };
  }

  bool get completed => closed || (shared && engine.phase != 'collecting');

  int participantRevision(String actor) =>
      participants[actor]?['revision'] as int? ?? 0;

  InteractiveMessage viewFor(String actor) {
    requireViewer(actor);
    final state = participants[actor];
    final current = state?['content'] as Map?;
    final presentationSource = current == null
        ? content
        : Map<String, Object?>.from(current);
    final presentation = InteractiveContent(presentationSource).json;
    return InteractiveMessage(
      revision: revision,
      content:
          hasInteraction &&
              participation['_creatorId'] == actor &&
              presentation['type'] == 'InteractionCard'
          ? {...presentation, 'showStatistics': true}
          : presentation,
      states: states,
      participation: participation,
      interaction: interaction,
      session: session,
      snapshotView: snapshotView,
    );
  }

  InteractiveMessage forwardedFor(String actor) {
    final view = viewFor(actor);
    final saved = participants[actor]?['value'];
    return InteractiveMessage(
      revision: 1,
      content: InteractiveContent.transform(
        view.widgetTree.withButtons([
          for (final button in view.buttons)
            {
              'id': button['id'],
              'label': button['label'],
              'action': 'acknowledge',
              'repeatable': false,
              'disabled': true,
              if (button['questions'] != null) 'questions': button['questions'],
              if (button['style'] != null) 'style': button['style'],
            },
        ]),
        (node) =>
            !anonymous &&
                interactiveFieldTypes.contains(node['type']) &&
                saved is Map &&
                saved.containsKey(node['key']) &&
                interactiveFieldValueError(
                      node,
                      saved[node['key']],
                      submitting: false,
                    ) ==
                    null
            ? {...node, 'initialValue': saved[node['key']]}
            : node,
      ),
      participation: {
        'closed': true,
        if (anonymous) 'anonymous': true,
        if (isQuestionnaire) 'kind': 'questionnaire',
      },
      snapshotView: hasInteraction
          ? anonymous
                ? anonymousForwardView(interactionView(actor))
                : interactionView(actor)
          : null,
    );
  }

  /// The web page receives only the authenticated participant's projected data.
  Map<String, Object?> webViewFor(String actor) => {
    'revision': revision,
    'sessionVersion': sessionVersion,
    'participantRevision': participantRevision(actor),
    'callbackVersion':
        (participants[actor]?['callback'] as Map?)?['updatedAt'] ?? 0,
    if (participants[actor]?['callback'] case final callback?)
      'callback': callback,
    'buttons': viewFor(actor).buttons,
    'interactionView': interactionView(actor),
  };

  Map<String, Object?> readFor(String actor) => {
    ...viewFor(actor).toJson(),
    'definition': toJson(),
    'participantRevision': participantRevision(actor),
    if (hasInteraction) 'interactionView': interactionView(actor),
    if (participants[actor] != null) 'ownParticipation': participants[actor],
    if (visible('visibility', actor: actor))
      'participants': {
        for (final entry in choices.entries)
          entry.key: {
            'name': entry.value['name'],
            'buttonId': entry.value['buttonId'],
            'label': entry.value['label'],
            'updatedAt': entry.value['updatedAt'],
          },
      },
    if (visible('summaryVisibility', actor: actor)) 'summary': summary,
  };

  List<Map<String, Object?>> get summary => isQuestionnaire
      ? const []
      : interactionSummary(
          buttons.where((b) => !shared || b['action'] == 'submit').toList(),
          choices.values,
        );

  final int revision;
  final List<Map<String, Object?>> states;
  String get title => widgetTree.title;
  String get body => widgetTree.body;
  List<Map<String, Object?>> get buttons => widgetTree.buttons;

  factory InteractiveMessage.fromSnapshot(
    Map<String, dynamic> json,
    String actorId,
  ) => InteractiveMessage(
    content: Map<String, Object?>.from(json['content'] as Map),
    revision: json['revision'] as int,
    snapshotView: json['interactionView'] == null
        ? null
        : Map<String, Object?>.from(json['interactionView'] as Map),
    participation: Map<String, Object?>.from(json['participation'] as Map),
    participants: {
      if (json['selectedLabel'] != null || json['value'] != null)
        actorId: {
          'label': json['selectedLabel'],
          if (json['value'] != null) 'value': json['value'],
          if (json['callback'] != null) 'callback': json['callback'],
        },
    },
  );

  factory InteractiveMessage.fromDefinition(Map<String, Object?> json) {
    if ([
      'title',
      'body',
      'buttons',
      'buttonColumns',
      'showStatistics',
    ].any(json.containsKey)) {
      throw ArgumentError('交互消息使用 content 组件树，不再接受 title/body/buttons');
    }
    final tree = InteractiveContent(
      Map<String, Object?>.from(json['content'] as Map),
    );
    tree.validate();
    _validateButtonColumns(tree.json['buttonColumns']);
    final buttons = tree.buttons;
    if (buttons.length > 12) throw ArgumentError('最多 12 个动作');
    final states = (json['states'] as List? ?? const [])
        .map((state) => Map<String, Object?>.from(state as Map))
        .toList();
    if (states.length > 16) throw ArgumentError('最多 16 个卡片状态');
    final stateIds = <String>{};
    for (final state in states) {
      final id = state['id'];
      if (id is! String || id.isEmpty || !stateIds.add(id))
        throw ArgumentError('状态标识必须非空且唯一');
    }
    _validateButtons(buttons, stateIds);
    for (final state in states) {
      final tree = InteractiveContent(
        Map<String, Object?>.from(state['content'] as Map),
      );
      tree.validate();
      _validateButtonColumns(tree.json['buttonColumns']);
      final stateButtons = tree.buttons;
      if (stateButtons.length > 12) throw ArgumentError('每个状态最多 12 个动作');
      _validateButtons(stateButtons, stateIds);
    }
    final participation = json['participation'] as Map? ?? const {};
    if (participation.containsKey('kind') &&
        participation['kind'] != 'questionnaire') {
      throw ArgumentError('participation.kind 仅支持 questionnaire；普通交互省略此字段');
    }
    if (participation['anonymous'] != null &&
        participation['anonymous'] is! bool) {
      throw ArgumentError('anonymous 必须是布尔值');
    }
    if (participation['showHistory'] != null &&
        participation['showHistory'] is! bool) {
      throw ArgumentError('showHistory 必须是布尔值');
    }
    if (participation['audience'] != null &&
        participation['excludedAudience'] != null) {
      throw ArgumentError('部分可见和部分不可见不能同时设置');
    }
    if (participation['excludedAudience'] is List &&
        (participation['excludedAudience'] as List).isEmpty) {
      throw ArgumentError('不可见范围不能为空；全部可见请省略 excludedAudience');
    }
    for (final key in [
      'audience',
      'excludedAudience',
      'visibilityActors',
      'visibilityExcludedActors',
      'summaryVisibilityActors',
      'visibilityImmediateActors',
      'summaryVisibilityImmediateActors',
    ]) {
      if (participation[key] case final value?) {
        if (value is! List || value.any((id) => id is! String || id.isEmpty))
          throw ArgumentError('$key 必须为参与者标识列表');
      }
    }
    if (participation['visibilityActors'] != null &&
        participation['visibilityExcludedActors'] != null) {
      throw ArgumentError('回答的部分可见和部分不可见不能同时设置');
    }
    for (final field in ['visibility', 'summaryVisibility']) {
      final timing = participation['${field}Timing'];
      if (timing != null && !['immediate', 'onComplete'].contains(timing))
        throw ArgumentError('$field 公布时机必须是 immediate 或 onComplete');
    }
    if (participation['callbackEvents'] case final events?) {
      if (events is! List ||
          events.any(
            (event) => !['vote', 'complete', 'pause'].contains(event),
          ) ||
          events.toSet().length != events.length)
        throw ArgumentError('callbackEvents 使用不重复的 vote、complete、pause 事件');
    }
    return InteractiveMessage.fromJson(json);
  }

  // System notices carry audience metadata, not an actionable card.
  factory InteractiveMessage.fromJson(Map<String, Object?> json) {
    final states = (json['states'] as List? ?? const [])
        .map((state) => Map<String, Object?>.from(state as Map))
        .toList();
    final interaction = Map<String, Object?>.from(
      json['interaction'] as Map? ?? const {},
    );
    if (interaction['actorWeights'] case final Map weights) {
      final actors = interaction['actors'] as List;
      if (weights.entries.any(
        (entry) =>
            !actors.contains(entry.key) ||
            entry.value is! num ||
            !(entry.value as num).isFinite ||
            (entry.value as num) <= 0,
      )) {
        throw ArgumentError('投票权重必须属于本轮参与者且是有限正数');
      }
    }
    return InteractiveMessage(
      content: Map<String, Object?>.from(json['content'] as Map),
      snapshotView: json['snapshotView'] == null
          ? null
          : Map<String, Object?>.from(json['snapshotView'] as Map),
      interaction: interaction,
      session: interaction.isEmpty
          ? const {}
          : Map<String, Object?>.from(
              json['session'] as Map? ?? SharedInteraction.initial(interaction),
            ),
      revision: json['revision'] as int,
      states: states,
      participation: Map<String, Object?>.from(
        json['participation'] as Map? ?? const {},
      ),
      participants: {
        for (final entry in (json['participants'] as Map? ?? const {}).entries)
          entry.key as String: Map<String, Object?>.from(entry.value as Map),
      },
    );
  }

  static void _validateButtonColumns(Object? value) {
    if (value != null && (value is! int || (value != 1 && value != 2))) {
      throw ArgumentError('按钮列数只支持 1 或 2');
    }
  }

  static void _validateButtons(
    List<Map<String, Object?>> buttons,
    Set<String> stateIds,
  ) {
    final ids = <String>{};
    for (final b in buttons) {
      if (!ids.add(b['id'] as String) ||
          (b['id'] as String).isEmpty ||
          (b['label'] as String).trim().isEmpty ||
          (b['label'] as String).length > 80 ||
          ![
            'update',
            'acknowledge',
            'openUrl',
            'openConversation',
            'submit',
            'nextRound',
          ].contains(b['action']) ||
          b['repeatable'] is! bool) {
        throw ArgumentError('按钮标识需唯一，文字不能为空，动作需有效');
      }
      if (b['selection'] case final Map config) {
        if (b['action'] != 'submit' || b['input'] != null)
          throw ArgumentError('选择列表使用 submit，不能同时配置页面输入');
        InteractiveSelection(Map<String, Object?>.from(config)).validate();
      }
      if (b['input'] != null &&
          (b['action'] != 'submit' || !['text', 'json'].contains(b['input']))) {
        throw ArgumentError('输入端点使用 submit 和 text/json');
      }
      if (b['questions'] != null && b['questions'] is! List) {
        throw ArgumentError('questions 必须是问题列表');
      }
      if (b['questions'] case final List questions) {
        if (b['action'] != 'submit' ||
            b['input'] != null ||
            b['selection'] != null) {
          throw ArgumentError('问题组使用 submit，不能同时配置 selection 或 input');
        }
        QuestionBatch(questions).validate();
      }
      if (b['completedLabel'] != null &&
          (b['completedLabel'] is! String ||
              (b['completedLabel'] as String).trim().isEmpty ||
              (b['completedLabel'] as String).length > 80))
        throw ArgumentError('完成后的按钮文字需为 1–80 字');
      if (b['notifyAi'] != null && b['notifyAi'] is! bool)
        throw ArgumentError('notifyAi 必须是布尔值');
      if (b['disabled'] != null && b['disabled'] is! bool)
        throw ArgumentError('按钮禁用状态必须为布尔值');
      if (b['style'] != null &&
          ![
            'normal',
            'primary',
            'info',
            'warning',
            'danger',
            'success',
          ].contains(b['style']))
        throw ArgumentError('不支持的按钮样式');
      if (b['icon'] != null && !interactiveButtonIcons.contains(b['icon']))
        throw ArgumentError('不支持的按钮图标');
      if (b['showArrow'] != null && b['showArrow'] is! bool)
        throw ArgumentError('箭头参数必须为布尔值');
      if (b['action'] == 'openUrl') {
        final uri = Uri.tryParse(b['url'] as String? ?? '');
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw ArgumentError('按钮链接必须是完整 HTTPS 地址');
        }
      }
      if (b['action'] == 'openConversation' &&
          (b['conversationId'] is! String ||
              (b['conversationId'] as String).isEmpty)) {
        throw ArgumentError('会话卡片需要目标会话');
      }
      if (b['nextBody'] is String && (b['nextBody'] as String).length > 10000)
        throw ArgumentError('更新正文最多 10000 字');
      if (b['nextState'] != null && !stateIds.contains(b['nextState']))
        throw ArgumentError('nextState 必须指向已定义的状态');
      if (b['action'] == 'update' &&
          ((b['nextBody'] is String) == (b['nextState'] is String))) {
        throw ArgumentError('更新按钮需要 nextBody 或 nextState，二选一');
      }
    }
  }

  Map<String, Object?> toJson({bool includeParticipants = false}) => {
    'revision': revision,
    'content': content,
    if (snapshotView != null) 'snapshotView': snapshotView,
    'participation': {...participation, if (closed) 'closed': true},
    if (interaction.isNotEmpty) 'interaction': interaction,
    if (includeParticipants && session.isNotEmpty) 'session': session,
    if (includeParticipants && participants.isNotEmpty)
      'participants': participants,
    if (states.isNotEmpty) 'states': states,
  };
}

typedef InteractiveClickResult = ({InteractiveMessage card, String? url});

class InteractiveMessageChanged extends StateError {
  InteractiveMessageChanged(this.card) : super('已同步到最新进度，请按当前卡片继续');
  final InteractiveMessage card;
}
