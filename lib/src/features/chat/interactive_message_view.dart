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
  });
  final InteractiveMessage card;
  final String actorId;
  final bool readOnly;
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
                _card.participantRevision(widget.actorId))) {
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
        setState(() => _acceptCard(result.card));
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = _card.viewFor(widget.actorId);
    final selected = _card.participants[widget.actorId];
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
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
          if (card.closed || (card.singleChoice && selected != null)) ...[
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
          const SizedBox(height: 16),
          for (final (index, button) in card.buttons.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            InteractiveMessageButton(
              button: button,
              busy: _busy == button['id'],
              locked: _busy != null || widget.readOnly || card.closed,
              onPressed: () => _click(button),
            ),
          ],
        ],
      ),
    );
  }
}
