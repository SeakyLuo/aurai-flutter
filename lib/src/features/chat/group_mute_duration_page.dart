import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../domain/group_mute.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMuteDurationPage extends StatefulWidget {
  const GroupMuteDurationPage({super.key, this.allowPermanent = true});
  final bool allowPermanent;
  @override
  State<GroupMuteDurationPage> createState() => _GroupMuteDurationPageState();
}

class _GroupMuteDurationPageState extends State<GroupMuteDurationPage> {
  Duration? _duration = const Duration(minutes: 10);
  Duration? _customDuration;
  bool _custom = false;
  Future<void> _pickCustom() async {
    final value = await showDialog<Duration>(
      context: context,
      builder: (_) => _CustomMuteDuration(
        initial: _customDuration ?? const Duration(minutes: 10),
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      _custom = true;
      _customDuration = value;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '选择禁言时长',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '完成',
          icon: Icons.check_rounded,
          iconWidget: const SettingsIcon(type: SettingsIconType.check),
          onPressed: () => Navigator.pop(context, (
            duration: _custom ? _customDuration : _duration,
          )),
        ),
      ],
    ),
    body: ListView(
      padding: settingsPagePadding(
        context,
        const EdgeInsets.fromLTRB(16, 8, 16, 32),
      ),
      children: [
        Material(
          color: settingsFieldColor(context),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (widget.allowPermanent) _choice('永久禁言', null),
              _choice('10 分钟', const Duration(minutes: 10)),
              _choice('1 小时', const Duration(hours: 1)),
              _choice('12 小时', const Duration(hours: 12)),
              _choice('1 天', const Duration(days: 1)),
              ListTile(
                minTileHeight: 60,
                title: const Text('自定义', style: TextStyle(fontSize: 15)),
                trailing: _custom
                    ? const SettingsIcon(type: SettingsIconType.check)
                    : null,
                onTap: _pickCustom,
              ),
              if (_custom)
                ListTile(
                  minTileHeight: 60,
                  title: const Text('禁言时长', style: TextStyle(fontSize: 15)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_customDuration!.inDays} 天 ${_customDuration!.inHours % 24} 小时 ${_customDuration!.inMinutes % 60} 分钟',
                      ),
                      const SizedBox(width: 8),
                      const SettingsIcon(type: SettingsIconType.chevron),
                    ],
                  ),
                  onTap: _pickCustom,
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _choice(String text, Duration? duration) => ListTile(
    minTileHeight: 60,
    title: Text(text, style: const TextStyle(fontSize: 15)),
    trailing: !_custom && _duration == duration
        ? const SettingsIcon(type: SettingsIconType.check)
        : null,
    onTap: () => setState(() {
      _custom = false;
      _duration = duration;
    }),
  );
}

class _CustomMuteDuration extends StatefulWidget {
  const _CustomMuteDuration({required this.initial});
  final Duration initial;
  @override
  State<_CustomMuteDuration> createState() => _CustomMuteDurationState();
}

class _CustomMuteDurationState extends State<_CustomMuteDuration> {
  late int _days = widget.initial.inDays;
  late int _hours = widget.initial.inHours % 24;
  late int _minutes = widget.initial.inMinutes % 60;
  Duration get _duration =>
      Duration(days: _days, hours: _hours, minutes: _minutes);
  final _controllers = <FixedExtentScrollController>[];
  @override
  void initState() {
    super.initState();
    _controllers.addAll([
      FixedExtentScrollController(initialItem: _days),
      FixedExtentScrollController(initialItem: _hours),
      FixedExtentScrollController(initialItem: _minutes),
    ]);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '自定义禁言时长',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                _wheel(
                  0,
                  '天',
                  GroupMute.maxDuration.inDays + 1,
                  (value) => _days = value,
                ),
                _wheel(1, '小时', 24, (value) => _hours = value),
                _wheel(2, '分钟', 60, (value) => _minutes = value),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '最多 30 天',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DialogActionButton(
                  text: '取消',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DialogActionButton(
                  text: '确认',
                  onPressed:
                      _duration == Duration.zero ||
                          _duration > GroupMute.maxDuration
                      ? null
                      : () => Navigator.pop(context, _duration),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _wheel(
    int index,
    String unit,
    int count,
    void Function(int) changed,
  ) => Expanded(
    child: CupertinoPicker.builder(
      scrollController: _controllers[index],
      itemExtent: 40,
      childCount: count,
      onSelectedItemChanged: (value) => setState(() => changed(value)),
      itemBuilder: (context, value) => Center(
        child: Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 17,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}
