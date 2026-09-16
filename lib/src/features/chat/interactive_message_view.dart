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
    int participantRevision,
  )
  onClick;
  final Future<void> Function(String url) onOpenLink;
  @override
  State<InteractiveMessageView> createState() => _InteractiveMessageViewState();
}

class _InteractiveMessageViewState extends State<InteractiveMessageView> {
  String? _busy;
  bool _editing = false;
  late InteractiveMessage _card = widget.card;

  @override
  void didUpdateWidget(InteractiveMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actorId != oldWidget.actorId) {
      _card = widget.card;
      _editing = false;
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
      if (next.shared &&
          (next.engine.phase != 'collecting' ||
              (_card.shared && next.engine.round != _card.engine.round))) {
        _editing = false;
      }
      _card = next;
    }
  }

  Future<void> _click(Map<String, Object?> button) async {
    if (_busy != null) return;
    setState(() => _busy = button['id'] as String);
    try {
      final result = await widget.onClick(
        button['id'] as String,
        _card.revision,
        _card.participantRevision(widget.actorId),
      );
      if (result != null && mounted) {
        setState(() {
          _acceptCard(result.card);
          _editing = false;
        });
        if (result.url != null) await widget.onOpenLink(result.url!);
      }
    } on Object catch (error) {
      if (mounted && error is InteractiveMessageChanged)
        setState(() => _acceptCard(error.card));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
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
          _editing = false;
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
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
          if (callbackLocked || callbackStatus == 'failed') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (callbackLocked && !widget.historical) ...[
                  const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: callbackStatus == 'failed'
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(callback!['error'] as String),
                            ),
                          )
                        : null,
                    child: Text(
                      callbackStatus == 'queued'
                          ? '等待 AI 处理'
                          : callbackStatus == 'processing'
                          ? 'AI 正在处理'
                          : '处理未完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (callbackStatus == 'failed' && canRetry)
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
              view: sharedView,
              shared: _card.shared,
              buttons: card.buttons,
              readOnly:
                  widget.readOnly ||
                  callbackLocked ||
                  widget.historical ||
                  _card.snapshotView != null,
              allowChange: _card.hasInteraction && _card.engine.allowChange,
              eligible:
                  !_card.shared ||
                  _card.interaction['actors'] == null ||
                  (_card.interaction['actors'] as List).contains(
                    widget.actorId,
                  ),
              editing: _editing,
              busy: _busy,
              onEditing: (value) => setState(() => _editing = value),
              onClick: _click,
            )
          else
            for (final (index, button) in card.buttons.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              InteractiveMessageButton(
                button: button,
                busy: _busy == button['id'],
                locked:
                    _busy != null ||
                    widget.readOnly ||
                    card.closed ||
                    callbackLocked,
                onPressed: () => _click(button),
              ),
            ],
        ],
      ),
    );
  }
}
