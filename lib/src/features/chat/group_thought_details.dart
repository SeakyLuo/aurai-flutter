part of 'group_activity_sheet.dart';

class _GroupThoughtDetails extends StatefulWidget {
  const _GroupThoughtDetails({
    required this.controller,
    required this.conversationId,
    required this.activity,
    this.reasonTitle,
    this.reason,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;
  final String? reasonTitle;
  final String? reason;

  @override
  State<_GroupThoughtDetails> createState() => _GroupThoughtDetailsState();
}

class _GroupThoughtDetailsState extends State<_GroupThoughtDetails> {
  late GroupMemberActivity _activity = widget.activity;
  late var _activities = widget.activity.activities;
  late final _updates = Listenable.merge([
    widget.controller,
    widget.controller.groupActivityChanges,
    widget.controller.groupSleepChanges,
  ]);
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _updates.addListener(_sync);
    _sync();
  }

  void _sync() {
    final current = widget.controller
        .groupActivitiesFor(widget.conversationId)
        .where((activity) => activity.runId == widget.activity.runId)
        .firstOrNull;
    setState(() {
      _running = current != null;
      if (current != null) _activity = current;
      _activities =
          current?.activities ??
          widget.controller.groupRunActivities(
            widget.conversationId,
            widget.activity.sender.id,
            widget.activity.runId,
          ) ??
          _activities;
    });
  }

  @override
  void dispose() {
    _updates.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GroupRunDetailsLayout(
      controller: widget.controller,
      sender: _activity.sender,
      conversationId: widget.conversationId,
      activity: _running ? _activity : null,
      children: [
        if (widget.reason == null && _activities.isEmpty)
          ThinkingIndicator(
            label: _running ? _activity.description : '本轮已结束',
            fontSize: 15,
            animate:
                _running && !_activity.stopping && !_activity.waitingForUser,
          ),
        if (widget.reason != null) ...[
          Text(
            widget.reasonTitle!,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SelectableText(
            widget.reason!,
            style: const TextStyle(fontSize: 15, height: 1.65),
          ),
        ],
        for (final (index, activity) in _activities.indexed)
          if (activity.toolName != null)
            ToolActivityView(
              key: ValueKey('${_activity.runId}:$index'),
              storageId: '${_activity.runId}:$index',
              title: activity.text,
              toolName: activity.toolName,
              status: activity.status!,
              requestJson: activity.requestJson,
              resultJson: activity.resultJson,
              startedAt: activity.startedAt,
              finishedAt: activity.finishedAt,
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                activity.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
      ],
    );
  }
}
