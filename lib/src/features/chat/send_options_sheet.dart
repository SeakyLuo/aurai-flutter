import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import 'draft_visibility_sheet.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'visibility_option_tile.dart';

class SendOptionsSheet extends StatefulWidget {
  const SendOptionsSheet({
    super.key,
    required this.members,
    required this.onChanged,
    this.initial,
    this.mentionedMemberIds = const {},
  });

  final List<MessageSender> members;
  final DraftVisibility? initial;
  final Set<String> mentionedMemberIds;
  final ValueChanged<DraftVisibility> onChanged;

  @override
  State<SendOptionsSheet> createState() => _SendOptionsSheetState();
}

class _SendOptionsSheetState extends State<SendOptionsSheet> {
  late DraftVisibility? _visibility = widget.initial;
  late final _selections = <DraftVisibilityMode, DraftVisibility>{
    for (final entry
        in widget.initial?.selections.entries ??
            const <MapEntry<DraftVisibilityMode, List<MessageSender>>>[])
      entry.key: DraftVisibility(entry.key, entry.value),
    if (widget.initial case final initial?) initial.mode: initial,
  };

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
          initial:
              _selections[mode] ??
              (mode == DraftVisibilityMode.included
                  ? DraftVisibility(
                      mode,
                      widget.members
                          .where(
                            (member) =>
                                widget.mentionedMemberIds.contains(member.id),
                          )
                          .toList(),
                    )
                  : null),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _visibility = result;
      _selections[mode] = result;
    });
  }

  void _save() {
    final current =
        _visibility ?? const DraftVisibility(DraftVisibilityMode.everyone, []);
    widget.onChanged(
      DraftVisibility(
        current.mode,
        current.members,
        selections: {
          for (final entry in _selections.entries)
            if (entry.key != DraftVisibilityMode.everyone)
              entry.key: entry.value.members,
        },
      ),
    );
    Navigator.pop(context);
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
              SettingsGlassAction(
                label: '保存',
                icon: Icons.check_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.check),
                onPressed: _save,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final mode in DraftVisibilityMode.values)
            VisibilityOptionTile(
              selected:
                  (_visibility?.mode ?? DraftVisibilityMode.everyone) == mode,
              opensMembers: mode != DraftVisibilityMode.everyone,
              title: switch (mode) {
                DraftVisibilityMode.everyone => '所有人可见',
                DraftVisibilityMode.included => '部分人可见',
                DraftVisibilityMode.excluded => '部分人不可见',
              },
              subtitle:
                  mode != DraftVisibilityMode.everyone &&
                      _selections.containsKey(mode)
                  ? _selections[mode]!.label
                  : null,
              onTap: () {
                if (mode == DraftVisibilityMode.everyone) {
                  const value = DraftVisibility(
                    DraftVisibilityMode.everyone,
                    [],
                  );
                  setState(() => _visibility = value);
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
