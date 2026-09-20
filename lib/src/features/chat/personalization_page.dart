import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/ai_profile.dart';
import 'package:flutter/material.dart';
import '../../agent/system_prompt.dart';
import '../../domain/response_preferences.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'personalization_controls.dart';
import 'personality_traits_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({
    super.key,
    required this.controller,
    required this.profile,
  });
  final ChatController controller;
  final AiProfile profile;
  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<PersonalizationPage> {
  late AiProfile _profile = widget.profile;
  late final _prompt = TextEditingController(text: _saved);
  late final _instructions = TextEditingController(
    text: _profile.preferences.customInstructions,
  );
  late var _preferences = _profile.preferences.responses;
  bool _saving = false;
  bool _allowPop = false;
  bool _advanced = false;
  String get _saved => _profile.preferences.systemPrompt;
  bool get _dirty =>
      _prompt.text != _saved ||
      _instructions.text != _profile.preferences.customInstructions ||
      !_preferences.sameAs(_profile.preferences.responses);

  @override
  void initState() {
    super.initState();
    _prompt.addListener(_changed);
    _instructions.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _prompt.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '个性化设置还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save' && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      final next = _profile.copyWith(
        preferences: AiPreferences(
          systemPrompt: _prompt.text,
          customInstructions: _instructions.text,
          responses: _preferences,
          screenAccess: _profile.preferences.screenAccess,
          reasoning: _profile.preferences.reasoning,
        ),
      );
      await widget.controller.saveAi(next);
      _profile = next;
      if (mounted) _notice('个性化设置已保存');
      return true;
    } on Object catch (error) {
      if (mounted) _notice('保存失败，请重试：${errorMessage(error)}');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));

  void _editTraits() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalityTraitsPage(
          initial: _preferences.traits,
          onChanged: (traits) => setState(
            () => _preferences = ResponsePreferences(
              style: _preferences.style,
              traits: traits,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _description(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String hint, {
    bool system = false,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    minLines: system ? 6 : 3,
    maxLines: system ? 14 : 8,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    style: const TextStyle(fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: settingsFieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '${_profile.sender.name}的个性',
        onBack: _saving ? null : () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            onPressed: _dirty && !_saving ? _save : null,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _label('基础风格和语气'),
                PersonalizationChoiceRow(
                  title: _preferences.style.label,
                  selected: _preferences.style.name,
                  choices: [
                    for (final style in ResponseStyle.values)
                      PersonalizationChoice(
                        style.name,
                        style.label,
                        style.description,
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _preferences = ResponsePreferences(
                            style: ResponseStyle.values.byName(value),
                            traits: _preferences.traits,
                          ),
                        ),
                ),
                _description(
                  '这是 ${_profile.sender.name} 在与你对话时使用的主要语言风格和语气。这不会影响 ${_profile.sender.name} 的功能。',
                ),
                const SizedBox(height: 26),
                _label('特征'),
                for (final trait in ResponseTrait.values)
                  if (_preferences.level(trait) != TraitLevel.standard) ...[
                    _traitRow(trait),
                    const SizedBox(height: 12),
                  ],
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving ? null : _editTraits,
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('添加特征', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                _description('在基本风格和语调的基础上选择额外的自定义项。'),
                const SizedBox(height: 26),
                _label('自定义指令'),
                _field(
                  _instructions,
                  '共享你希望 ${_profile.sender.name} 纳入其回复考虑范围的内容。',
                ),
                const SizedBox(height: 26),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _advanced = !_advanced),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('高级', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _advanced ? -.25 : .25,
                          duration: const Duration(milliseconds: 200),
                          child: const SettingsIcon(
                            type: SettingsIconType.chevron,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  curve: Curves.easeInOutCubic,
                  child: _advanced
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 18,
                                right: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '系统提示词',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _saving ||
                                            _prompt.text == agentSystemPrompt
                                        ? null
                                        : () =>
                                              _prompt.text = agentSystemPrompt,
                                    child: const Text('恢复默认'),
                                  ),
                                ],
                              ),
                            ),
                            _field(_prompt, '输入系统提示词', system: true),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _traitRow(ResponseTrait trait) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _saving ? null : _editTraits,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_preferences.level(trait).label}${trait.label}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _preferences.level(trait) == TraitLevel.more
                  ? trait.more
                  : trait.less,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
