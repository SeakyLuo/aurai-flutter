import 'package:flutter/material.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProviderModelsPicker extends StatefulWidget {
  const ProviderModelsPicker({
    super.key,
    required this.models,
    required this.existing,
  });
  final List<String> models;
  final Set<String> existing;
  @override
  State<ProviderModelsPicker> createState() => _ProviderModelsPickerState();
}

class _ProviderModelsPickerState extends State<ProviderModelsPicker> {
  final _selected = <String>{};
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String model) {
    setState(() {
      if (!_selected.remove(model)) _selected.add(model);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final shown = widget.models
        .where((m) => m.toLowerCase().contains(query))
        .toList();
    final available = shown
        .where((model) => !widget.existing.contains(model))
        .toSet();
    final allSelected =
        available.isNotEmpty && available.every(_selected.contains);
    return Scaffold(
      appBar: SettingsAppBar(
        title: '选择要添加的模型',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: SettingsIcon(
              type: SettingsIconType.check,
              color: _selected.isEmpty
                  ? colors.onSurface.withValues(alpha: .3)
                  : colors.onSurface,
            ),
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索模型',
                  filled: true,
                  fillColor: settingsFieldColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        '没有匹配的模型',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (_, index) {
                        final model = shown[index];
                        final exists = widget.existing.contains(model);
                        final selected = _selected.contains(model);
                        return Semantics(
                          checked: exists || selected,
                          enabled: !exists,
                          child: ListTile(
                            title: Text(
                              model,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            enabled: !exists,
                            onTap: exists ? null : () => _toggle(model),
                            trailing: exists
                                ? Text(
                                    '已添加',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  )
                                : Container(
                                    width: 22,
                                    height: 22,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? colors.onSurface
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? colors.onSurface
                                            : colors.outline,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: selected
                                        ? SettingsIcon(
                                            type: SettingsIconType.check,
                                            color: colors.surface,
                                          )
                                        : null,
                                  ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选择 ${_selected.length} 个模型',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: available.isEmpty
                        ? null
                        : () => setState(() {
                            if (allSelected) {
                              _selected.removeAll(available);
                            } else {
                              _selected.addAll(available);
                            }
                          }),
                    child: Text(
                      allSelected
                          ? '取消全选'
                          : query.isEmpty
                          ? '全选'
                          : '全选搜索结果',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
