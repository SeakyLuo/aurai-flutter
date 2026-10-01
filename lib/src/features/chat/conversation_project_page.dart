import 'package:flutter/material.dart';

import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'project_list_tile.dart';
import 'project_profile_page.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ConversationProjectSelection {
  const ConversationProjectSelection(this.projectId);
  final String? projectId;
}

String conversationProjectChangedMessage(
  List<DevelopmentProject> projects,
  String? projectId,
) => projectId == null
    ? '已将会话移出项目'
    : '已将会话加入“${projects.singleWhere((project) => project.id == projectId).name}”';

class ConversationProjectSheet extends StatefulWidget {
  const ConversationProjectSheet({
    super.key,
    required this.controller,
    required this.projects,
    required this.selectedProjectId,
  });

  final ChatController controller;
  final List<DevelopmentProject> projects;
  final String? selectedProjectId;

  static Future<ConversationProjectSelection?> show(
    BuildContext context, {
    required ChatController controller,
    required List<DevelopmentProject> projects,
    required String? selectedProjectId,
  }) => showModalBottomSheet<ConversationProjectSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => ConversationProjectSheet(
      controller: controller,
      projects: projects,
      selectedProjectId: selectedProjectId,
    ),
  );

  @override
  State<ConversationProjectSheet> createState() =>
      _ConversationProjectSheetState();
}

class _ConversationProjectSheetState extends State<ConversationProjectSheet> {
  late List<DevelopmentProject> _projects = widget.projects;
  late String? _selectedProjectId = widget.selectedProjectId;

  bool get _changed => _selectedProjectId != widget.selectedProjectId;

  void _select(String? projectId) =>
      setState(() => _selectedProjectId = projectId);

  void _save() =>
      Navigator.pop(context, ConversationProjectSelection(_selectedProjectId));

  Future<void> _open(DevelopmentProject project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProjectProfilePage(controller: widget.controller, project: project),
      ),
    );
    final projects = await widget.controller.projects.list();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      if (_selectedProjectId != null &&
          !projects.any((item) => item.id == _selectedProjectId)) {
        _selectedProjectId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '所属项目',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SettingsGlassAction(
                    label: '保存',
                    icon: Icons.check_rounded,
                    iconWidget: SettingsIcon(
                      type: SettingsIconType.check,
                      color: colors.onSurface.withValues(
                        alpha: _changed ? 1 : .3,
                      ),
                    ),
                    onPressed: _changed ? _save : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: _projects.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  if (index == 0) return _noneItem();
                  final project = _projects[index - 1];
                  final selected = _selectedProjectId == project.id;
                  return Semantics(
                    checked: selected,
                    child: ProjectListTile(
                      project: project,
                      prefix: _selectionMark(
                        selected,
                        onTap: () => _select(project.id),
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _open(project),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionMark(bool selected, {VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    final mark = Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.onSurface : Colors.transparent,
        border: Border.all(
          color: selected ? colors.onSurface : colors.outline,
          width: 1.4,
        ),
      ),
      child: selected
          ? SettingsIcon(type: SettingsIconType.check, color: colors.surface)
          : null,
    );
    if (onTap == null) return mark;
    return Material(
      color: Colors.transparent,
      child: InkResponse(radius: 22, onTap: onTap, child: mark),
    );
  }

  Widget _noneItem() {
    final selected = _selectedProjectId == null;
    return Semantics(
      checked: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          minTileHeight: 64,
          minVerticalPadding: 8,
          horizontalTitleGap: 12,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          leading: SizedBox(
            width: 84,
            child: Row(
              children: [
                _selectionMark(selected),
                const SizedBox(width: 14),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(child: _NoProjectIcon()),
                ),
              ],
            ),
          ),
          title: const Text('不属于项目'),
          subtitle: const Text('从当前项目中移出'),
          onTap: () => _select(null),
        ),
      ),
    );
  }
}

class _NoProjectIcon extends StatelessWidget {
  const _NoProjectIcon();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _NoProjectIconPainter(
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _NoProjectIconPainter extends CustomPainter {
  const _NoProjectIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 12), 8, pen);
    canvas.drawLine(const Offset(6.35, 17.65), const Offset(17.65, 6.35), pen);
  }

  @override
  bool shouldRepaint(_NoProjectIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
