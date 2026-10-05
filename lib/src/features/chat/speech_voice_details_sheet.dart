import 'app_bottom_sheet.dart';
import 'app_sheet_body.dart';
import 'app_sheet_surface.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/speech_voice.dart';
import 'conversation_menu_icon.dart';
import 'provider_named_value_dialog.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'speech_voice_avatar.dart';

Future<void> showSpeechVoiceDetails(
  BuildContext context,
  SpeechVoice voice, {
  Future<bool> Function(SpeechVoice)? onRename,
}) => showAppBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  constraints: BoxConstraints(
    minHeight: MediaQuery.sizeOf(context).height * .4,
    maxHeight: MediaQuery.sizeOf(context).height * .8,
  ),
  builder: (_) => _SpeechVoiceDetailsSheet(voice: voice, onRename: onRename),
);

class _SpeechVoiceDetailsSheet extends StatefulWidget {
  const _SpeechVoiceDetailsSheet({required this.voice, this.onRename});
  final SpeechVoice voice;
  final Future<bool> Function(SpeechVoice)? onRename;
  @override
  State<_SpeechVoiceDetailsSheet> createState() =>
      _SpeechVoiceDetailsSheetState();
}

class _SpeechVoiceDetailsSheetState extends State<_SpeechVoiceDetailsSheet> {
  late SpeechVoice _voice = widget.voice;
  bool _saving = false;

  Future<void> _rename() async {
    final renamed = await editProviderNamedValue(
      context,
      title: '修改音色名称',
      valueLabel: '接口名称',
      initial: (id: _voice.id, name: _voice.name),
      editValue: false,
    );
    if (!mounted || renamed == null || renamed.name == _voice.name) return;
    final updated = _voice.renamed(renamed.name);
    setState(() => _saving = true);
    final saved = await widget.onRename!(updated);
    if (mounted)
      setState(() {
        _saving = false;
        if (saved) _voice = updated;
      });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = _voice.details;
    final gender = details?.gender;
    return AppSheetSurface(
      child: SafeArea(
        top: false,
        child: AppSheetBody(
          shrinkWrap: true,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    '音色详情',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.onRename != null)
                  SettingsGlassAction(
                    label: '修改名称',
                    icon: Icons.edit_rounded,
                    iconWidget: const ConversationMenuIcon(
                      type: ConversationMenuIconType.rename,
                    ),
                    onPressed: _saving ? null : _rename,
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SpeechVoiceAvatar(
                      name: _voice.name,
                      avatarUrl: _voice.avatarUrl,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _voice.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (gender == 'male' || gender == 'female') ...[
                                const SizedBox(width: 6),
                                Text(
                                  gender == 'male' ? '♂' : '♀',
                                  semanticsLabel: gender == 'male' ? '男' : '女',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: gender == 'male'
                                        ? GlobalUI.maleColor
                                        : GlobalUI.femaleColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (details != null && details.tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in details.tags)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.onSurface.withValues(
                                        alpha: .055,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (details != null && details.description.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      height: 1,
                      thickness: .5,
                      color: colors.outlineVariant.withValues(alpha: .45),
                    ),
                  ),
                  Text(
                    '声音特点',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.description,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
