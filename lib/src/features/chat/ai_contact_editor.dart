import 'dart:async';
import 'contact_generator.dart';
import 'glass_surface.dart';
import 'random_contact.dart';
import '../../domain/response_preferences.dart';
import 'personalization_controls.dart';
import 'personality_traits_page.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/ai_profile.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../domain/avatar_style.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'profile_avatar_editor.dart';
import 'custom_avatar_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class AiContactEditor extends StatefulWidget {
  const AiContactEditor({
    super.key,
    required this.controller,
    this.profile,
    this.onSaveDraft,
  });
  final ChatController controller;
  final AiProfile? profile;
  final Future<void> Function(AiProfile)? onSaveDraft;
  @override
  State<AiContactEditor> createState() => _AiContactEditorState();
}

class _AiContactEditorState extends State<AiContactEditor> {
  late final _name = TextEditingController(
    text: widget.profile?.sender.name ?? '',
  );
  late final _description = TextEditingController(
    text: widget.profile?.description ?? '',
  );
  late final _role = TextEditingController(
    text: [
      widget.profile?.instructions ?? '',
      widget.profile?.preferences.customInstructions ?? '',
    ].where((text) => text.trim().isNotEmpty).join('\n\n'),
  );
  late ResponsePreferences _responses =
      widget.profile?.preferences.responses ?? const ResponsePreferences();
  late AvatarStyle _avatar = AvatarStyle(
    icon: widget.profile?.sender.avatarIcon ?? 'initial',
    color: widget.profile?.sender.avatarColor ?? 'violet',
    path: widget.profile?.sender.avatarPath,
  );
  bool _saving = false, _changed = false, _allowPop = false;
  final _draftPaths = <String>{};
  final _editedText = <TextEditingController>{};
  bool _avatarEdited = false;
  bool _styleEdited = false;
  final _editedTraits = <ResponseTrait>{};
  final _generator = ContactGenerator();
  bool _rolling = false;
  Future<void> _roll() async {
    setState(() => _rolling = true);
    try {
      final color = _avatarEdited
          ? null
          : await RandomContact.savedAvatarColor();
      if (!mounted) return;
      final generated = await _generator.generate(widget.controller.config, {
        if (_editedText.contains(_name)) 'name': _name.text,
        if (_editedText.contains(_description))
          'description': _description.text,
        if (_editedText.contains(_role)) 'role': _role.text,
      });
      if (!mounted) return;

      setState(() {
        _rolling = false;
        if (!_editedText.contains(_name)) _name.text = generated.name;
        if (!_editedText.contains(_description))
          _description.text = generated.description;
        if (!_editedText.contains(_role)) {
          _role.text = generated.role;
        }
        if (!_avatarEdited)
          _avatar = AvatarStyle(icon: generated.avatar.icon, color: color!);
        _responses = ResponsePreferences(
          style: _styleEdited ? _responses.style : generated.responses.style,
          traits: {
            for (final trait in ResponseTrait.values)
              trait: _editedTraits.contains(trait)
                  ? _responses.level(trait)
                  : generated.responses.level(trait),
          },
        );
        _changed = true;
      });
    } catch (_) {
      if (mounted) _notice('生成失败，请检查头像色库是否有配色后重试');
    } finally {
      if (mounted) setState(() => _rolling = false);
    }
  }

  @override
  void dispose() {
    unawaited(_generator.cancel());
    _name.dispose();
    _description.dispose();
    _role.dispose();
    for (final path in _draftPaths) {
      File(path).delete();
    }
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _avatarSource(AvatarSource source) async {
    try {
      if (source == AvatarSource.custom) {
        final value = await Navigator.push<AvatarStyle>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CustomAvatarPage(initial: _avatar, name: _name.text),
          ),
        );
        if (mounted && value != null)
          setState(() {
            _avatarEdited = true;
            _avatar = value;
            _changed = true;
          });
      } else {
        final image = await ImagePicker().pickImage(
          source: source == AvatarSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 90,
        );
        if (image == null) return;
        final root = await getApplicationSupportDirectory();
        final directory = await Directory(
          '${root.path}/profile_avatars',
        ).create(recursive: true);
        final file = await File(image.path).copy(
          '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        _draftPaths.add(file.path);
        if (mounted)
          setState(() {
            _avatarEdited = true;
            _avatar = AvatarStyle(
              icon: _avatar.icon,
              color: _avatar.color,
              path: file.path,
            );
            _changed = true;
          });
      }
    } on Object {
      if (mounted) _notice('头像修改失败，请重试');
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _notice('请填写名字');
      return;
    }
    setState(() => _saving = true);
    try {
      final old = widget.profile;
      final config = widget.controller.modelSettings.activeConfig;
      final now = DateTime.now();
      final ai = AiProfile(
        sender: MessageSender(
          id: old?.sender.id ?? 'agent:${newMessageId()}',
          name: _name.text.trim(),
          kind: MessageSenderKind.agent,
          avatarIcon: _avatar.icon,
          avatarColor: _avatar.color,
          avatarPath: _avatar.path,
          archived: old?.sender.archived ?? false,
        ),
        description: _description.text.trim(),
        instructions: '',
        preferences: AiPreferences(
          systemPrompt:
              (old?.preferences ?? const AiPreferences()).systemPrompt,
          customInstructions: _role.text.trim(),
          responses: _responses,
          screenAccess: old?.preferences.screenAccess ?? false,
        ),
        modelSelection:
            old?.modelSelection ??
            AiModelSelection(
              provider: config.service,
              model: config.model,
              baseUrl: config.baseUrl,
            ),
        isTemporary: old?.isTemporary ?? false,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );
      if (widget.onSaveDraft != null) {
        await widget.onSaveDraft!(ai);
      } else {
        await widget.controller.saveAi(ai, create: old == null);
      }
      _draftPaths.remove(_avatar.path);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, ai.sender.id);
      }
    } on Object {
      if (mounted) _notice('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '朋友还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _save();
    } else {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_changed && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: widget.profile == null ? '新建朋友' : '个人资料',
        onBack: () => Navigator.maybePop(context),
        actions: [
          if (widget.profile == null)
            GlassSurface(
              radius: 28,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundAction(
                    label: '保存',
                    icon: Icons.check_rounded,
                    iconWidget: const SettingsIcon(
                      type: SettingsIconType.check,
                    ),
                    onPressed: _saving || _rolling ? null : _save,
                  ),
                  SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  RoundAction(
                    label: '随机生成',
                    icon: Icons.casino_outlined,
                    iconWidget: _rolling
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.65),
                          )
                        : const RollContactIcon(),
                    onPressed: _saving || _rolling ? null : _roll,
                  ),
                ],
              ),
            )
          else
            SettingsGlassAction(
              label: '保存',
              icon: Icons.check_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.check),
              onPressed: _saving || _rolling ? null : _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Center(
            child: ProfileAvatarEditor(
              style: _avatar,
              name: _name.text,
              onSelected: _saving || _rolling ? null : _avatarSource,
            ),
          ),
          const SizedBox(height: 24),
          _field('名字', _name),
          const SizedBox(height: 16),
          _field(
            '简介',
            _description,
            multiline: true,
            hint: '一句话介绍这个 AI，例如：帮你规划旅行的伙伴',
          ),
          const SizedBox(height: 16),
          _label('语气'),
          PersonalizationChoiceRow(
            title: _responses.style.label,
            selected: _responses.style.name,
            choices: [
              for (final style in ResponseStyle.values)
                PersonalizationChoice(
                  style.name,
                  style.label,
                  style.description,
                ),
            ],
            onChanged: _saving || _rolling
                ? null
                : (value) => setState(() {
                    _styleEdited = true;
                    _responses = ResponsePreferences(
                      style: ResponseStyle.values.byName(value),
                      traits: _responses.traits,
                    );
                    _changed = true;
                  }),
          ),
          const SizedBox(height: 16),
          _label('特征'),
          Material(
            color: settingsFieldColor(context),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _traitSummary,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SizedBox.square(
                      dimension: 24,
                      child: SettingsIcon(type: SettingsIconType.chevron),
                    ),
                  ],
                ),
              ),
              onTap: _saving || _rolling
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalityTraitsPage(
                          initial: _responses.traits,
                          onChanged: (traits) {
                            if (mounted)
                              setState(() {
                                for (final trait in ResponseTrait.values) {
                                  if ((traits[trait] ?? TraitLevel.standard) !=
                                      _responses.level(trait)) {
                                    _editedTraits.add(trait);
                                  }
                                }
                                _responses = ResponsePreferences(
                                  style: _responses.style,
                                  traits: traits,
                                );
                                _changed = true;
                              });
                          },
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            '自定义指令',
            _role,
            lines: 4,
            hint: '告诉 AI 应该怎么做，例如：规划旅行前先问预算，推荐时说明理由。',
          ),
        ],
      ),
    ),
  );
  String get _traitSummary {
    final values = [
      for (final trait in ResponseTrait.values)
        if (_responses.level(trait) != TraitLevel.standard)
          '${trait.label} · ${_responses.level(trait).label}',
    ];
    return values.isEmpty ? '默认' : values.join('、');
  }

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _field(
    String title,
    TextEditingController text, {
    int lines = 1,
    bool multiline = false,
    String? hint,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(title),
      TextField(
        controller: text,
        enabled: !_saving && !_rolling,
        minLines: lines,
        maxLines: multiline
            ? null
            : lines == 1
            ? 1
            : lines + 3,
        keyboardType: multiline || lines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        textInputAction: multiline || lines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        onChanged: (_) => setState(() {
          _editedText.add(text);
          _changed = true;
        }),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: lines == 1 ? 2 : lines,
          filled: true,
          fillColor: settingsFieldColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}
