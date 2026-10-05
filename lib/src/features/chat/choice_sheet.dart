import 'app_bottom_sheet.dart';
import 'app_sheet_surface.dart';
import 'floating_search_layout.dart';
import 'package:flutter/material.dart';
import '../../widgets/empty_data_view.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

typedef Choice<T> = ({T value, String label});

Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  T? selected,
  required List<Choice<T>> choices,
  String searchHint = '搜索选项',
  String emptyTitle = '没有匹配的选项',
  bool alwaysShowSearch = false,
  bool allowSearch = true,
  bool showTitle = true,
  bool showSelection = true,
  Widget? Function(T)? leadingBuilder,
  String Function(T)? searchText,
}) => showAppBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _ChoiceSheet<T>(
    title: title,
    selected: selected,
    choices: choices,
    searchHint: searchHint,
    emptyTitle: emptyTitle,
    alwaysShowSearch: alwaysShowSearch,
    allowSearch: allowSearch,
    showTitle: showTitle,
    showSelection: showSelection,
    leadingBuilder: leadingBuilder,
    searchText: searchText,
  ),
);

class _ChoiceSheet<T> extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    required this.searchHint,
    required this.emptyTitle,
    required this.alwaysShowSearch,
    required this.allowSearch,
    required this.showTitle,
    required this.showSelection,
    this.leadingBuilder,
    this.searchText,
    required this.selected,
  });

  final String title, searchHint, emptyTitle;
  final List<Choice<T>> choices;
  final T? selected;
  final bool showSelection;
  final bool alwaysShowSearch, showTitle;
  final bool allowSearch;
  final Widget? Function(T)? leadingBuilder;
  final String Function(T)? searchText;

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = widget.allowSearch && widget.choices.length >= 20
        ? _search.text.trim().toLowerCase()
        : '';
    final expanded = widget.alwaysShowSearch || widget.choices.length > 8;
    final shown = widget.choices
        .where(
          (choice) =>
              choice.label.toLowerCase().contains(query) ||
              (widget.searchText
                      ?.call(choice.value)
                      .toLowerCase()
                      .contains(query) ??
                  false),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: expanded ? .8 : null,
        child: AppSheetSurface(
          child: SafeArea(
            top: false,
            child: SearchSheetBody(
              header: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.showTitle)
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 60),
                          child: Center(
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        SettingsGlassAction(
                          label: '关闭',
                          icon: Icons.close_rounded,
                          iconWidget: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ],
                ),
              ),
              child: FloatingSearchLayout(
                controller: _search,
                onChanged: (_) => setState(() {}),
                hintText: widget.searchHint,
                enabled: widget.allowSearch && widget.choices.length >= 20,
                bottom: 16,
                child: shown.isEmpty
                    ? Center(child: EmptyDataView(title: widget.emptyTitle))
                    : Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                        ),
                        child: ListView.builder(
                          shrinkWrap: !expanded,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            expanded ? 68 : 0,
                            12,
                            widget.allowSearch && widget.choices.length >= 20
                                ? FloatingSearchLayout.clearance
                                : 16,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final choice = shown[index];
                            final selected = choice.value == widget.selected;
                            return Semantics(
                              checked: widget.showSelection ? selected : null,
                              inMutuallyExclusiveGroup: widget.showSelection,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                leading: widget.showSelection
                                    ? Container(
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
                                      )
                                    : null,
                                title: Row(
                                  children: [
                                    if (widget.leadingBuilder?.call(
                                          choice.value,
                                        )
                                        case final icon?) ...[
                                      icon,
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        choice.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () =>
                                    Navigator.pop(context, choice.value),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              shrinkWrap: !expanded,
            ),
          ),
        ),
      ),
    );
  }
}

class ChoiceField extends StatelessWidget {
  const ChoiceField({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: onTap == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
