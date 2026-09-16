class InteractiveMessage {
  const InteractiveMessage({
    required this.revision,
    required this.title,
    required this.body,
    required this.buttons,
    this.states = const [],
    this.participation = const {},
    this.participants = const {},
  });
  final Map<String, Object?> participation;
  final Map<String, Map<String, Object?>> participants;
  bool get closed => participation['closed'] == true;
  bool get singleChoice => participation['selectionMode'] == 'singleChoice';
  bool visible(String field) => switch (participation[field] ?? 'public') {
    'public' => true,
    'afterClose' => closed,
    _ => false,
  };
  int participantRevision(String actor) =>
      participants[actor]?['revision'] as int? ?? 0;

  InteractiveMessage viewFor(String actor) {
    final state = participants[actor];
    final current = state?.containsKey('buttons') == true ? state : null;
    return InteractiveMessage(
      revision: revision,
      title: current?['title'] as String? ?? title,
      body: current?['body'] as String? ?? body,
      buttons: current == null
          ? buttons
          : (current['buttons'] as List)
                .map((b) => Map<String, Object?>.from(b as Map))
                .toList(),
      states: states,
      participation: participation,
    );
  }

  Map<String, Object?> readFor(String actor) => {
    ...viewFor(actor).toJson(),
    'definition': toJson(),
    'participantRevision': participantRevision(actor),
    if (participants[actor] != null) 'ownParticipation': participants[actor],
    if (visible('visibility'))
      'participants': {
        for (final entry in participants.entries)
          entry.key: {
            'name': entry.value['name'],
            'buttonId': entry.value['buttonId'],
            'label': entry.value['label'],
            'updatedAt': entry.value['updatedAt'],
          },
      },
    if (visible('summaryVisibility')) 'summary': summary,
  };

  List<Map<String, Object?>> get summary {
    final counts = <(String, String), Map<String, Object?>>{
      for (final button in buttons)
        (button['id'] as String, button['label'] as String): {
          'buttonId': button['id'],
          'label': button['label'],
          'count': 0,
        },
    };
    for (final state in participants.values) {
      final id = state['buttonId'] as String;
      final entry = counts.putIfAbsent((
        id,
        state['label'] as String,
      ), () => {'buttonId': id, 'label': state['label'], 'count': 0});
      entry['count'] = (entry['count'] as int) + 1;
    }
    return counts.values.toList();
  }

  final int revision;
  final List<Map<String, Object?>> states;
  final String title;
  final String body;
  final List<Map<String, Object?>> buttons;

  factory InteractiveMessage.fromSnapshot(
    Map<String, dynamic> json,
    String actorId,
  ) => InteractiveMessage(
    revision: json['revision'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    buttons: (json['buttons'] as List)
        .map((b) => Map<String, Object?>.from(b as Map))
        .toList(),
    participation: Map<String, Object?>.from(json['participation'] as Map),
    participants: {
      if (json['selectedLabel'] != null)
        actorId: {'label': json['selectedLabel']},
    },
  );

  factory InteractiveMessage.fromJson(Map<String, Object?> json) {
    final title = json['title'] as String;
    final body = json['body'] as String;
    final buttons = (json['buttons'] as List)
        .map((b) => Map<String, Object?>.from(b as Map))
        .toList();
    if (title.trim().isEmpty ||
        title.length > 100 ||
        body.length > 10000 ||
        buttons.isEmpty ||
        buttons.length > 12) {
      throw ArgumentError('请提供标题、最多 10000 字正文和 1–12 个按钮');
    }
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
      final stateTitle = state['title'] as String;
      final stateBody = state['body'] as String;
      final stateButtons = (state['buttons'] as List)
          .map((b) => Map<String, Object?>.from(b as Map))
          .toList();
      if (stateTitle.trim().isEmpty ||
          stateTitle.length > 100 ||
          stateBody.length > 10000 ||
          stateButtons.isEmpty ||
          stateButtons.length > 12)
        throw ArgumentError('每个状态需要标题、最多 10000 字正文和 1–12 个按钮');
      _validateButtons(stateButtons, stateIds);
    }
    return InteractiveMessage(
      revision: json['revision'] as int,
      title: title,
      body: body,
      buttons: buttons,
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
          !['update', 'acknowledge', 'openUrl'].contains(b['action']) ||
          b['repeatable'] is! bool) {
        throw ArgumentError('按钮标识需唯一，文字不能为空，动作需有效');
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
      if (b['icon'] != null &&
          ![
            'none',
            'info',
            'play',
            'reset',
            'delete',
            'check',
            'open',
            'settings',
          ].contains(b['icon']))
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
    'participation': participation,
    if (includeParticipants && participants.isNotEmpty)
      'participants': participants,
    'title': title,
    'body': body,
    'buttons': buttons,
    if (states.isNotEmpty) 'states': states,
  };
}

typedef InteractiveClickResult = ({InteractiveMessage card, String? url});

class InteractiveMessageChanged extends StateError {
  InteractiveMessageChanged(this.card) : super('已同步到最新进度，请按当前卡片继续');
  final InteractiveMessage card;
}
