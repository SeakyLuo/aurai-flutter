import '../../app/glass_notice.dart';
import 'interactive_button_layout.dart';
import 'interaction_content.dart';
import '../../domain/error_message.dart';
import 'interactive_message_button.dart';
import 'package:flutter/material.dart';
import '../../domain/interactive_message.dart';

class InteractiveMessageView extends StatefulWidget {
  const InteractiveMessageView({
    super.key,
    required this.card,
    required this.onClick,
    required this.onOpenLink,
    this.actorId = 'user:local',
    this.readOnly = false,
    this.titleTrailing,
    this.historical = false,
    this.onRetry,
  });
  final InteractiveMessage card;
  final String actorId;
  final bool readOnly;
  final bool historical;
  final Future<InteractiveMessage> Function(String eventId)? onRetry;
  final Widget? titleTrailing;
  final Future<InteractiveClickResult?> Function(
    String buttonId,
    int revision,
    int participantRevision, {
    Object? value,
  })
  onClick;
  final Future<void> Function(String url) onOpenLink;
  @override
  State<InteractiveMessageView> createState() => _InteractiveMessageViewState();
}

class _InteractiveMessageViewState extends State<InteractiveMessageView> {
  String? _busy;
  late InteractiveMessage _card = widget.card;

  @override
  void didUpdateWidget(InteractiveMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actorId != oldWidget.actorId) {
      _card = widget.card;
    } else {
      _acceptCard(widget.card);
    }
  }

  void _acceptCard(InteractiveMessage next) {
    if (next.revision > _card.revision ||
        (next.revision == _card.revision &&
            next.participantRevision(widget.actorId) >=
                _card.participantRevision(widget.actorId) &&
            next.sessionVersion >= _card.sessionVersion &&
            (next.participantRevision(widget.actorId) >
                    _card.participantRevision(widget.actorId) ||
                ((next.participants[widget.actorId]?['callback']
                                as Map?)?['updatedAt']
                            as int? ??
                        0) >=
                    ((_card.participants[widget.actorId]?['callback']
                                as Map?)?['updatedAt']
                            as int? ??
                        0)))) {
      _card = next;
    }
  }

  Future<void> _click(Map<String, Object?> button, {Object? value}) async {
    if (_busy != null) return;
    setState(() => _busy = button['id'] as String);
    try {
      final result = await widget.onClick(
        button['id'] as String,
        _card.revision,
        _card.participantRevision(widget.actorId),
        value: value,
      );
      if (result != null && mounted) {
        setState(() {
          _acceptCard(result.card);
        });
        if (result.url != null) await widget.onOpenLink(result.url!);
      }
    } on Object catch (error) {
      if (mounted && error is InteractiveMessageChanged)
        setState(() => _acceptCard(error.card));
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : '操作失败，请重试：${errorMessage(error)}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _retry(String eventId) async {
    if (_busy != null) return;
    setState(() => _busy = eventId);
    try {
      final card = await widget.onRetry!(eventId);
      if (mounted)
        setState(() {
          _acceptCard(card);
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = _card.viewFor(widget.actorId);
    final selected = _card.participants[widget.actorId];
    final callback = selected?['callback'] as Map?;
    final callbackStatus = callback?['status'];
    final callbackLocked = ['queued', 'processing'].contains(callbackStatus);
    final pendingButtonId = callbackLocked
        ? (callback?['buttonId'] ?? selected?['buttonId']) as String?
        : null;
    final canRetry =
        !widget.readOnly &&
        !widget.historical &&
        _card.snapshotView == null &&
        widget.onRetry != null;
    final sharedView = widget.historical
        ? _card.snapshotView
        : _card.hasInteraction
        ? _card.interactionView(widget.actorId)
        : null;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  card.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (widget.titleTrailing case final trailing?) trailing,
            ],
          ),
          if (card.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              card.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: colors.onSurface,
              ),
            ),
          ],
          if (sharedView == null &&
              (card.closed || (card.singleChoice && selected != null))) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (card.closed) '已结束',
                if (card.singleChoice && selected != null)
                  '已选：${selected['label']}',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          if (callbackStatus == 'failed') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showGlassSnackBar(
                      SnackBar(content: Text(callback!['error'] as String)),
                    ),
                    child: Text(
                      '处理未完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (canRetry)
                  TextButton(
                    onPressed: _busy == null
                        ? () => _retry(callback!['id'] as String)
                        : null,
                    child: const Text('重试'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (sharedView != null)
            InteractionContent(
              key: ValueKey((widget.actorId, card.title, card.body)),
              view: sharedView,
              shared: _card.shared,
              buttons: card.buttons,
              buttonColumns: card.buttonColumns,
              readOnly:
                  widget.readOnly ||
                  widget.historical ||
                  _card.snapshotView != null,
              pendingButtonId: pendingButtonId,
              allowChange: _card.hasInteraction && _card.engine.allowChange,
              eligible:
                  !_card.shared ||
                  _card.interaction['actors'] == null ||
                  (_card.interaction['actors'] as List).contains(
                    widget.actorId,
                  ),
              busy: _busy,
              onClick: _click,
            )
          else
            InteractiveButtonLayout(
              columns: card.buttonColumns,
              children: [
                for (final button in card.buttons)
                  InteractiveMessageButton(
                    button: button,
                    busy: _busy == button['id'],
                    locked:
                        _busy != null ||
                        widget.readOnly ||
                        card.closed ||
                        pendingButtonId == button['id'],
                    onPressed: () => _click(button),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
