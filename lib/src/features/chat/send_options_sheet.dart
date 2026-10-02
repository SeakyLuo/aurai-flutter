import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import 'draft_visibility_sheet.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class SendOptionsSheet extends StatefulWidget {
  const SendOptionsSheet({
    super.key,
    required this.members,
    required this.onChanged,
    this.initial,
  });

  final List<MessageSender> members;
  final DraftVisibility? initial;
  final ValueChanged<DraftVisibility> onChanged;

  @override
  State<SendOptionsSheet> createState() => _SendOptionsSheetState();
}

class _SendOptionsSheetState extends State<SendOptionsSheet> {
  late DraftVisibility? _visibility = widget.initial;

  Future<void> _edit(DraftVisibilityMode mode) async {
    final result = await showModalBottomSheet<DraftVisibility>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraftVisibilitySheet(
          mode: mode,
          members: widget.members,
          initial: _visibility?.mode == mode ? _visibility : null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _visibility = result);
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SettingsGlassAction(
                label: '关闭',
                icon: Icons.close_rounded,
                iconWidget: const QuestionIcon(type: QuestionIconType.close),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  '本条消息可见范围',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 12),
          for (final mode in DraftVisibilityMode.values)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(switch (mode) {
                DraftVisibilityMode.everyone => '所有人可见',
                DraftVisibilityMode.included => '部分人可见',
                DraftVisibilityMode.excluded => '部分人不可见',
              }),
              subtitle:
                  _visibility?.mode == mode &&
                      mode != DraftVisibilityMode.everyone
                  ? Text(
                      _visibility!.members
                          .map((member) => member.name)
                          .join('、'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((_visibility?.mode ?? DraftVisibilityMode.everyone) ==
                      mode)
                    const SettingsIcon(type: SettingsIconType.check),
                  if (mode != DraftVisibilityMode.everyone) ...[
                    const SizedBox(width: 8),
                    const SettingsIcon(type: SettingsIconType.chevron),
                  ],
                ],
              ),
              onTap: () {
                if (mode == DraftVisibilityMode.everyone) {
                  const value = DraftVisibility(
                    DraftVisibilityMode.everyone,
                    [],
                  );
                  setState(() => _visibility = value);
                  widget.onChanged(value);
                } else {
                  _edit(mode);
                }
              },
            ),
        ],
      ),
    ),
  );
}
