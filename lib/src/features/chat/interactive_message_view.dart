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
  });
  final InteractiveMessage card;
  final Future<String?> Function(String buttonId, int revision) onClick;
  final Future<void> Function(String url) onOpenLink;
  @override
  State<InteractiveMessageView> createState() => _InteractiveMessageViewState();
}

class _InteractiveMessageViewState extends State<InteractiveMessageView> {
  String? _busy;
  Future<void> _click(Map<String, Object?> button) async {
    if (_busy != null) return;
    setState(() => _busy = button['id'] as String);
    try {
      final url = await widget.onClick(
        button['id'] as String,
        widget.card.revision,
      );
      if (url != null && mounted) await widget.onOpenLink(url);
    } on Object catch (error) {
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.card.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          if (widget.card.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.card.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: colors.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final (index, button) in widget.card.buttons.indexed) ...[
            if (index > 0) const SizedBox(height: 8),
            InteractiveMessageButton(
              button: button,
              busy: _busy == button['id'],
              locked: _busy != null,
              onPressed: () => _click(button),
            ),
          ],
        ],
      ),
    );
  }
}
