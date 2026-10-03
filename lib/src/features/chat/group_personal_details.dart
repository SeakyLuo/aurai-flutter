import 'settings_appearance.dart';
import 'group_nickname_visibility.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../storage/group_member_details.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_icon.dart';

class GroupPersonalDetails extends StatefulWidget {
  const GroupPersonalDetails({
    super.key,
    required this.store,
    required this.groupId,
    required this.joinedAt,
    required this.defaultName,
    required this.onChanged,
    required this.builder,
  });
  final GroupMemberDetailsStore store;
  final String groupId, defaultName;
  final DateTime joinedAt;
  final Future<void> Function() onChanged;
  final Widget Function(Widget remark, Widget identity) builder;

  @override
  State<GroupPersonalDetails> createState() => _GroupPersonalDetailsState();
}

class _GroupPersonalDetailsState extends State<GroupPersonalDetails> {
  ({String nickname, String remark})? _details;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await runUiAction(context, () async {
      final details = await widget.store.read(widget.groupId);
      if (mounted) setState(() => _details = details);
    });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit(bool nickname) async {
    final current = _details!;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => GroupDetailEditor(
        title: nickname ? '我在群里的昵称' : '备注',
        description: nickname ? '仅在这个群使用，清空后使用原名。' : '仅自己可见，不修改群名称。',
        initialValue: nickname
            ? (current.nickname.isEmpty ? widget.defaultName : current.nickname)
            : current.remark,
        maxLength: nickname ? 32 : 200,
      ),
    );
    if (!mounted || value == null) return;
    setState(() => _saving = true);
    await runUiAction(context, () async {
      await widget.store.save(
        widget.groupId,
        nickname: nickname ? value : current.nickname,
        remark: nickname ? current.remark : value,
      );
      await widget.onChanged();
      final details = await widget.store.read(widget.groupId);
      if (mounted) setState(() => _details = details);
    });
    if (mounted) setState(() => _saving = false);
  }

  Widget _row(String title, String value, {VoidCallback? onTap}) => ListTile(
    contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
    minTileHeight: settingsCardHeight,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: SizedBox(
      width: MediaQuery.sizeOf(context).width * .43,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ],
      ),
    ),
    onTap: _saving ? null : onTap,
  );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null)
      return ListTile(
        title: const Text('个人群资料'),
        trailing: _loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: _load, child: const Text('重试')),
      );
    final joined = widget.joinedAt;
    return widget.builder(
      _row(
        '备注',
        details.remark.isEmpty ? '未设置' : details.remark,
        onTap: () => _edit(false),
      ),
      Column(
        children: [
          _row(
            '我在群里的昵称',
            details.nickname.isEmpty ? widget.defaultName : details.nickname,
            onTap: () => _edit(true),
          ),
          GroupNicknameVisibility(
            groupId: widget.groupId,
            builder: (context, show) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('显示群成员昵称', style: TextStyle(fontSize: 15)),
              value: show,
              onChanged: (value) => runUiAction(
                context,
                () => GroupNicknamePreference.forGroup(
                  widget.groupId,
                ).save(value),
              ),
            ),
          ),
          _row('进群时间', '${joined.year}年${joined.month}月${joined.day}日'),
        ],
      ),
    );
  }
}

class GroupDetailEditor extends StatefulWidget {
  const GroupDetailEditor({
    super.key,
    required this.title,
    required this.description,
    required this.initialValue,
    required this.maxLength,
  });
  final String title, description, initialValue;
  final int maxLength;
  @override
  State<GroupDetailEditor> createState() => _GroupDetailEditorState();
}

class _GroupDetailEditorState extends State<GroupDetailEditor> {
  late final _text = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DialogActionButton(
                  text: '取消',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DialogActionButton(
                  text: '保存',
                  onPressed: () => Navigator.pop(context, _text.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
