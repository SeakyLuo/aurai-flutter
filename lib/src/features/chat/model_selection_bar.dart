import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'sidebar_action_icon.dart';
import 'settings_appearance.dart';
import '../../app/global_ui.dart';

class ModelSelectionBar extends StatefulWidget {
  const ModelSelectionBar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onSelectAll,
    this.searchHintText = '搜索模型',
  });
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final int selectedCount, totalCount;
  final bool allSelected;
  final VoidCallback? onSelectAll;
  final String searchHintText;
  @override
  State<ModelSelectionBar> createState() => _ModelSelectionBarState();
}

class _ModelSelectionBarState extends State<ModelSelectionBar> {
  final _focus = FocusNode();
  bool _searching = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _fold() {
    _focus.unfocus();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = widget.search.text.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween(end: _searching ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        onEnd: () {
          if (_searching) _focus.requestFocus();
        },
        builder: (context, t, _) {
          final left =
              (constraints.maxWidth - RoundAction.defaultSize) * (1 - t);
          return SizedBox(
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 48,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: _searching,
                    child: Opacity(
                      opacity: 1 - t,
                      child: GlassSurface(
                        radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 18, right: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '已选 ${widget.selectedCount} / ${widget.totalCount}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onSelectAll,
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.onSurface,
                                ),
                                child: Text(widget.allSelected ? '取消全选' : '全选'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  width: 40 + (constraints.maxWidth - 88) * t,
                  top: 4 * (1 - t),
                  bottom: 4 * (1 - t),
                  child: const SettingsGlassActionSurface(
                    child: SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: left,
                  width: 40,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: RoundAction(
                      label: filtered
                          ? '搜索中：${widget.search.text}'
                          : widget.searchHintText,
                      icon: Icons.search_rounded,
                      iconWidget: SidebarActionIcon(
                        type: SidebarActionIconType.search,
                        color: filtered
                            ? GlobalUI.highlightTextColor(context)
                            : colors.onSurfaceVariant,
                      ),
                      onPressed: () {
                        if (_searching) {
                          _focus.requestFocus();
                        } else {
                          setState(() => _searching = true);
                        }
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 44,
                  right: 48,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_searching || t < 1,
                    child: ExcludeSemantics(
                      excluding: !_searching,
                      child: Opacity(
                        opacity: ((t - .7) / .3).clamp(0.0, 1.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: widget.search,
                                focusNode: _focus,
                                onChanged: widget.onSearchChanged,
                                onTapOutside: (_) => _focus.unfocus(),
                                onSubmitted: (_) => _fold(),
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: widget.searchHintText,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.search.text.isNotEmpty)
                              IconButton(
                                tooltip: '清空输入',
                                onPressed: () {
                                  widget.search.clear();
                                  widget.onSearchChanged('');
                                },
                                icon: const QuestionIcon(
                                  type: QuestionIconType.close,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  width: 40,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_searching,
                    child: Opacity(
                      opacity: t,
                      child: Center(
                        child: SettingsGlassAction(
                          label: '折叠搜索',
                          icon: Icons.close_rounded,
                          iconWidget: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                          onPressed: _fold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
