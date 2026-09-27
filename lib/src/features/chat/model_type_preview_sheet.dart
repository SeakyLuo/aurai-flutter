import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../providers/model_catalog.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';
import 'model_search_field.dart';
import 'settings_icon.dart';

Future<void> showModelTypePreviewSheet(
  BuildContext context, {
  required Future<List<Map<String, dynamic>>> Function() loadEntries,
  required String Function(Map<String, dynamic>) purposeLabel,
  required Future<void> Function(Map<String, dynamic>) onOpen,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _ModelTypePreviewSheet(
    loadEntries: loadEntries,
    purposeLabel: purposeLabel,
    onOpen: onOpen,
  ),
);

class _ModelTypePreviewSheet extends StatefulWidget {
  const _ModelTypePreviewSheet({
    required this.loadEntries,
    required this.purposeLabel,
    required this.onOpen,
  });
  final Future<List<Map<String, dynamic>>> Function() loadEntries;
  final String Function(Map<String, dynamic>) purposeLabel;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  @override
  State<_ModelTypePreviewSheet> createState() => _ModelTypePreviewSheetState();
}

class _ModelTypePreviewSheetState extends State<_ModelTypePreviewSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await runUiAction(context, () async {
      final entries = await widget.loadEntries();
      if (mounted) setState(() => _entries = entries);
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final entries = (_entries ?? <Map<String, dynamic>>[])
        .where(
          (entry) =>
              (entry['id'] as String).toLowerCase().contains(query) ||
              modelDisplayName(
                entry['id'] as String,
              ).toLowerCase().contains(query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .8,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        '预览效果',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ModelSearchField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  hintText: '搜索模型',
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries == null
                    ? Center(
                        child: TextButton(
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      )
                    : entries.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty ? '暂无模型' : '没有匹配的模型',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              modelDisplayName(entry['id'] as String),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: Text(
                              widget.purposeLabel(entry),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            trailing: const SettingsIcon(
                              type: SettingsIconType.chevron,
                            ),
                            onTap: () => widget.onOpen(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
