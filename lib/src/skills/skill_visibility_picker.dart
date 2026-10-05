import '../features/chat/app_bottom_sheet.dart';
import '../app/global_ui.dart';
import '../features/chat/settings_appearance.dart';
import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/visibility_option_tile.dart';
import 'skill_store.dart';
import '../domain/resource_scope.dart';
import '../features/chat/resource_scope_picker.dart';
import 'skill_visibility_targets.dart';

String skillVisibilityLabel(
  String value, {
  List<ResourceScope> scopes = const [],
}) => switch (value) {
  'public' => scopes.isEmpty ? '所有人可见' : '部分可见',
  'partial' => '部分可见',
  'selected' => '部分可见',
  _ => '仅自己可见',
};

Future<(String, Set<String>, List<ResourceScope>)?> showSkillVisibilityPicker(
  BuildContext context, {
  required SkillStore store,
  required String visibility,
  required Set<String> selected,
  required List<ResourceScope> scopes,
}) => showAppBottomSheet<(String, Set<String>, List<ResourceScope>)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(borderRadius: GlobalUI.bottomSheetBorderRadius),
  builder: (_) => SkillVisibilityPicker(
    store: store,
    visibility: visibility,
    selected: selected,
    scopes: scopes,
  ),
);

class SkillVisibilityPicker extends StatefulWidget {
  const SkillVisibilityPicker({
    super.key,
    required this.store,
    required this.visibility,
    required this.selected,
    required this.scopes,
  });
  final SkillStore store;
  final String visibility;
  final Set<String> selected;
  final List<ResourceScope> scopes;
  @override
  State<SkillVisibilityPicker> createState() => _SkillVisibilityPickerState();
}

class _SkillVisibilityPickerState extends State<SkillVisibilityPicker> {
  late String _visibility =
      widget.visibility == 'selected' ||
          (widget.visibility == 'public' && widget.scopes.isNotEmpty)
      ? 'partial'
      : widget.visibility;
  late List<ResourceScope> _scopes = [...widget.scopes];
  late Set<String> _selected = {...widget.selected};

  Future<void> _chooseTargets() async {
    try {
      final avatars = await widget.store.visibilityGroupAvatars();
      if (!mounted) return;
      final result =
          await showAppBottomSheet<(Set<String>, List<ResourceScope>)>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: false,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: GlobalUI.bottomSheetBorderRadius,
            ),
            builder: (_) => ClipRRect(
              borderRadius: GlobalUI.bottomSheetBorderRadius,
              child: SkillVisibilityTargets(
                store: widget.store,
                groupAvatars: avatars,
                selected: _selected,
                scopes: _scopes,
              ),
            ),
          );
      if (!mounted || result == null) return;
      setState(() {
        _selected = result.$1;
        _scopes = result.$2;
        _visibility = 'partial';
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VisibilityHeader(
            title: '可见范围',
            actionLabel: '保存',
            onDone:
                _visibility == 'partial' && _selected.isEmpty && _scopes.isEmpty
                ? null
                : () => Navigator.pop(context, (
                    _visibility == 'partial'
                        ? (_scopes.isEmpty ? 'selected' : 'public')
                        : _visibility,
                    _visibility == 'partial' ? _selected : <String>{},
                    _visibility == 'partial' ? _scopes : <ResourceScope>[],
                  )),
          ),
          const SizedBox(height: 12),
          for (final value in ['public', 'partial', 'private'])
            VisibilityOptionTile(
              selected: _visibility == value,
              opensMembers: value == 'partial',
              title: skillVisibilityLabel(value),
              subtitle:
                  value == 'partial' &&
                      (_selected.isNotEmpty || _scopes.isNotEmpty)
                  ? [
                      ...widget.store.members
                          .where((m) => _selected.contains(m.id))
                          .map((m) => m.name),
                      if (_scopes.isNotEmpty)
                        resourceScopeLabel(
                          _scopes,
                          widget.store.groups,
                          widget.store.projects,
                        ),
                    ].join('、')
                  : null,
              onTap: value == 'partial'
                  ? _chooseTargets
                  : () => setState(() => _visibility = value),
            ),
        ],
      ),
    ),
  );
}

class _VisibilityHeader extends StatelessWidget {
  const _VisibilityHeader({
    required this.title,
    required this.onDone,
    this.actionLabel = '完成',
  });
  final String title;
  final VoidCallback? onDone;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SettingsGlassAction(
            label: '关闭',
            icon: Icons.close_rounded,
            iconWidget: const QuestionIcon(type: QuestionIconType.close),
            onPressed: () => Navigator.pop(context),
          ),
          SettingsGlassAction(
            label: actionLabel,
            icon: Icons.check_rounded,
            iconWidget: SettingsIcon(
              type: SettingsIconType.check,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: onDone == null ? .3 : 1,
              ),
            ),
            onPressed: onDone,
          ),
        ],
      ),
    ],
  );
}
