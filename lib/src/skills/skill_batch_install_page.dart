import 'package:flutter/material.dart';

import '../features/chat/model_selection_bar.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../widgets/empty_data_view.dart';
import 'skill_store.dart';

class SkillBatchInstallPage extends StatefulWidget {
  const SkillBatchInstallPage({super.key, required this.candidates});
  final List<SkillInstallCandidate> candidates;

  @override
  State<SkillBatchInstallPage> createState() => _SkillBatchInstallPageState();
}

class _SkillBatchInstallPageState extends State<SkillBatchInstallPage> {
  final _selected = <String>{};
  final _search = TextEditingController();
  late final _available = widget.candidates
      .where((c) => !c.installed && c.visible)
      .map((c) => c.sender.id)
      .toSet();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final shown = widget.candidates
        .where((c) => c.sender.name.toLowerCase().contains(query))
        .toList();
    final uninstalled = shown.where((c) => !c.installed).toList();
    final installed = shown.where((c) => c.installed).toList();
    final entries = <(String?, SkillInstallCandidate?)>[
      if (uninstalled.isNotEmpty) ('未安装', null),
      for (final candidate in uninstalled) (null, candidate),
      if (installed.isNotEmpty) ('已安装', null),
      for (final candidate in installed) (null, candidate),
    ];
    final availableShown = shown
        .map((c) => c.sender.id)
        .where(_available.contains)
        .toSet();
    final allSelected =
        availableShown.isNotEmpty && availableShown.every(_selected.contains);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '批量安装',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '安装所选 AI',
            icon: Icons.check_rounded,
            iconWidget: SettingsIcon(
              type: SettingsIconType.check,
              color: SettingsGlassAction.foregroundColor(
                context,
                enabled: _selected.isNotEmpty,
              ),
            ),
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected),
          ),
        ],
      ),
      body: SettingsPageBody(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: shown.isEmpty
                        ? Center(
                            child: EmptyDataView(
                              title: widget.candidates.isEmpty
                                  ? '群内暂无 AI'
                                  : '没有匹配的成员',
                            ),
                          )
                        : ListView.builder(
                            padding: settingsPagePadding(
                              context,
                              const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            ),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              if (entry.$1 case final title?) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    16,
                                    6,
                                    8,
                                  ),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              return _member(entry.$2!);
                            },
                          ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: ModelSelectionBar(
                      search: _search,
                      searchHintText: '搜索群成员',
                      onSearchChanged: (_) => setState(() {}),
                      selectedCount: _selected.length,
                      totalCount: _available.length,
                      allSelected: allSelected,
                      onSelectAll: availableShown.isEmpty
                          ? null
                          : () => setState(() {
                              if (allSelected) {
                                _selected.removeAll(availableShown);
                              } else {
                                _selected.addAll(availableShown);
                              }
                            }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _member(SkillInstallCandidate candidate) {
    final colors = Theme.of(context).colorScheme;
    final enabled = _available.contains(candidate.sender.id);
    final selected = _selected.contains(candidate.sender.id);
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .5,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          horizontalTitleGap: 12,
          minTileHeight: 72,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: MemberAvatar(sender: candidate.sender, size: 48),
          title: Text(
            candidate.sender.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          trailing: !candidate.visible && !candidate.installed
              ? Text(
                  '不可见',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : selected
              ? SettingsIcon(
                  type: SettingsIconType.check,
                  color: colors.onSurface,
                )
              : null,
          onTap: !enabled
              ? null
              : () => setState(() {
                  if (!_selected.remove(candidate.sender.id))
                    _selected.add(candidate.sender.id);
                }),
        ),
      ),
    );
  }
}
