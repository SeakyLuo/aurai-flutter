import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:async';
import 'friend_notification.dart';
import 'contact_generator.dart';
import 'glass_surface.dart';
import 'random_contact.dart';
import '../../domain/response_preferences.dart';
import '../../domain/profile_gender.dart';
import 'profile_gender_field.dart';
import '../../domain/model_reasoning.dart';
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
  late ProfileGender _gender =
      widget.profile?.preferences.gender ?? ProfileGender.unknown;
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
  bool _notifyFriend = true;
  final _draftPaths = <String>{};
  final _editedText = <TextEditingController>{};
  bool _avatarEdited = false;
  bool _styleEdited = false;
  bool _genderEdited = false;
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
        if (_genderEdited) 'gender': _gender.name,
      });
      if (!mounted) return;

      setState(() {
        _rolling = false;
        if (!_genderEdited) _gender = generated.gender;
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
    } catch (caughtError) {
      if (mounted)
        _notice(
          '生成失败，请检查头像色库是否有配色后重试：${errorMessage(caughtError)}',
          kind: ToastKind.error,
        );
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

  void _notice(String text, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(text)), kind: kind);
  Future<void> _avatarSource(AvatarSource source) async {
    try {
      if (source == AvatarSource.custom) {
        final value = await Navigator.push<AvatarStyle>(
          context,
          MaterialPageRoute(
            builder: (_) => CustomAvatarPage(
              initial: _avatar,
              name: _name.text,
              database: widget.controller.groupStore.database,
            ),
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
    } on Object catch (error) {
      if (mounted)
        _notice('头像修改失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _notice('请填写名字');
      return;
    }
    if (_name.text.characters.length > AiProfile.nameMaxLength) {
      _notice('名字最多 ${AiProfile.nameMaxLength} 个字符');
      return;
    }
    if (_description.text.characters.length > AiProfile.descriptionMaxLength) {
      _notice('简介最多 ${AiProfile.descriptionMaxLength} 个字符');
      return;
    }
    if (_role.text.characters.length > AiProfile.instructionsMaxLength) {
      _notice('自定义指令最多 ${AiProfile.instructionsMaxLength} 个字符');
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
        instructions: old?.instructions ?? '',
        preferences: AiPreferences(
          gender: _gender,
          systemPrompt:
              (old?.preferences ?? const AiPreferences()).systemPrompt,
          customInstructions: _role.text.trim(),
          responses: _responses,
          screenAccess: old?.preferences.screenAccess ?? false,
          speech: old?.preferences.speech,
          reasoning: old?.preferences.reasoning ?? ModelReasoning.inherit,
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
        previousUpdatedAt: old?.updatedAt,
      );
      if (widget.onSaveDraft != null) {
        await widget.onSaveDraft!(ai);
      } else if (old == null) {
        await widget.controller.addAiFriend(
          ai,
          create: true,
          notifyFriend: _notifyFriend,
        );
      } else {
        await widget.controller.saveAi(ai, addToMyContacts: false);
      }
      _draftPaths.remove(_avatar.path);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, ai.sender.id);
      }
    } on Object catch (error) {
      if (mounted)
        _notice('保存失败，请重试：${errorMessage(error)}', kind: ToastKind.error);
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
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: widget.profile == null ? '新建朋友' : '个人资料',
        onBack: () => Navigator.maybePop(context),
        actions: [
          if (widget.profile == null)
            SettingsGlassActionSurface(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  RoundAction(
                    label: '保存',
                    icon: Icons.check_rounded,
                    iconWidget: const SettingsIcon(
                      type: SettingsIconType.check,
                    ),
                    onPressed: _saving || _rolling ? null : _save,
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
        padding: EdgeInsets.fromLTRB(
          16,
          settingsHeaderHeight(context) + 12,
          16,
          32,
        ),
        children: [
          Center(
            child: ProfileAvatarEditor(
              style: _avatar,
              name: _name.text,
              onSelected: _saving || _rolling ? null : _avatarSource,
            ),
          ),
          const SizedBox(height: 24),
          _field('名字', _name, maxLength: AiProfile.nameMaxLength),
          const SizedBox(height: 16),
          ProfileGenderField(
            value: _gender,
            onChanged: _saving || _rolling
                ? null
                : (value) => setState(() {
                    _gender = value;
                    _genderEdited = true;
                    _changed = true;
                  }),
          ),
          const SizedBox(height: 16),
          _field(
            '简介',
            _description,
            maxLength: AiProfile.descriptionMaxLength,
            multiline: true,
            hint: '一句话介绍这位联系人，例如：帮你规划旅行的伙伴',
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
                padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 12, 18),
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
            maxLength: AiProfile.instructionsMaxLength,
            lines: 4,
            hint: '描述工作方式，例如：规划旅行前先问预算，推荐时说明理由。',
          ),
          if (widget.profile == null && widget.onSaveDraft == null) ...[
            const SizedBox(height: 16),
            FriendNotificationSwitch(
              value: _notifyFriend,
              onChanged: _saving || _rolling
                  ? null
                  : (value) => setState(() {
                      _notifyFriend = value;
                      _changed = true;
                    }),
            ),
          ],
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
    required int maxLength,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(title),
      TextField(
        controller: text,
        enabled: !_saving && !_rolling,
        maxLength: maxLength,
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
