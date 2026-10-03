part of 'group_activity_sheet.dart';

class _StopMemberButton extends StatefulWidget {
  const _StopMemberButton({
    required this.controller,
    required this.conversationId,
    required this.activity,
    this.style = SettingsActionStyle.glass,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;
  final SettingsActionStyle style;

  @override
  State<_StopMemberButton> createState() => _StopMemberButtonState();
}

class _StopMemberButtonState extends State<_StopMemberButton> {
  bool _busy = false;
  bool _retry = false;

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _retry = false;
    });
    try {
      await widget.controller.stopGroupMember(
        conversationId: widget.conversationId,
        senderId: widget.activity.sender.id,
        runId: widget.activity.runId,
      );
    } on Object catch (error) {
      if (mounted) {
        _retry = true;
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('终止失败：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopping = _busy || (widget.activity.stopping && !_retry);
    final colors = Theme.of(context).colorScheme;
    return SettingsGlassAction(
      style: widget.style,
      label: stopping ? '终止中' : '终止思考',
      icon: Icons.stop_rounded,
      onPressed: stopping ? null : _stop,
      iconWidget: SizedBox.square(
        dimension: 20,
        child: Center(
          child: stopping
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.65,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
      ),
    );
  }
}
