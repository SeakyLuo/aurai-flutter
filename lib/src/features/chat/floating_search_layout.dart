import 'app_sheet_body.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'sidebar_action_icon.dart';

/// The library search pattern, shared by pages and selection sheets.
class FloatingSearchLayout extends StatefulWidget {
  const FloatingSearchLayout({
    super.key,
    required this.controller,
    required this.hintText,
    required this.child,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.suffixIcon,
    this.trailingAction,
    this.enabled = true,
    this.autofocus = false,
    this.bottom = 16,
    this.itemCount,
  });

  final TextEditingController controller;
  final String hintText;
  final Widget child;
  final ValueChanged<String>? onChanged, onSubmitted;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final Widget? trailingAction;
  final bool enabled, autofocus;
  final double bottom;
  final int? itemCount;
  static const double clearance = 88;
  static const double fieldHeight = 48;

  @override
  State<FloatingSearchLayout> createState() => _FloatingSearchLayoutState();
}

/// Sheets keep their controls above the scrolling content, like page AppBars.
class SearchSheetBody extends AppSheetBody {
  const SearchSheetBody({
    super.key,
    required super.header,
    required super.child,
    super.shrinkWrap,
  });
}

class _FloatingSearchLayoutState extends State<FloatingSearchLayout> {
  final _focus = FocusNode();
  FocusNode get _searchFocus => widget.focusNode ?? _focus;
  Timer? _reveal;
  bool _hidden = false;

  @override
  void dispose() {
    _reveal?.cancel();
    _focus.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        _searchFocus.hasFocus ||
        !widget.enabled)
      return false;
    if (notification is ScrollStartNotification) {
      _reveal?.cancel();
      if (!_hidden) setState(() => _hidden = true);
    } else if (notification is ScrollEndNotification) {
      _reveal?.cancel();
      _reveal = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _hidden = false);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final showSearch =
        widget.enabled &&
        (widget.itemCount == null ||
            widget.itemCount! >= 20 ||
            widget.controller.text.isNotEmpty);
    if (!showSearch && widget.trailingAction == null) return widget.child;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (showSearch || widget.trailingAction != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: widget.bottom,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: _hidden,
                  child: AnimatedSlide(
                    offset: _hidden ? const Offset(0, 1.5) : Offset.zero,
                    duration: duration,
                    child: AnimatedOpacity(
                      opacity: _hidden ? 0 : 1,
                      duration: duration,
                      child: Row(
                        children: [
                          if (showSearch)
                            Expanded(
                              child: GlassSurface(
                                radius: 28,
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: widget.controller,
                                    builder: (context, value, _) => TextField(
                                      controller: widget.controller,
                                      focusNode: _searchFocus,
                                      autofocus: widget.autofocus,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      onChanged: widget.onChanged,
                                      onTapOutside: (_) =>
                                          _searchFocus.unfocus(),
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (value) {
                                        _searchFocus.unfocus();
                                        widget.onSubmitted?.call(value);
                                      },
                                      decoration: InputDecoration(
                                        hintText: widget.hintText,
                                        isDense: true,
                                        filled: false,
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
                                              0,
                                              10,
                                              14,
                                              10,
                                            ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 40,
                                              maxWidth: 40,
                                              minHeight: FloatingSearchLayout
                                                  .fieldHeight,
                                              maxHeight: FloatingSearchLayout
                                                  .fieldHeight,
                                            ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            right: 8,
                                          ),
                                          child: Center(
                                            child: SizedBox.square(
                                              dimension: 20,
                                              child: SidebarActionIcon(
                                                type: SidebarActionIconType
                                                    .search,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                        suffixIcon:
                                            widget.suffixIcon ??
                                            (value.text.isEmpty
                                                ? null
                                                : IconButton(
                                                    tooltip: '清除搜索',
                                                    icon: const QuestionIcon(
                                                      type: QuestionIconType
                                                          .close,
                                                    ),
                                                    onPressed: () {
                                                      widget.controller.clear();
                                                      widget.onChanged?.call(
                                                        '',
                                                      );
                                                    },
                                                  )),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (widget.trailingAction case final action?) ...[
                            const SizedBox(width: 8),
                            action,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
