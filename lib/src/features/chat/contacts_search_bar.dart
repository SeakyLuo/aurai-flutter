import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

class ContactsSearchBar extends StatelessWidget {
  const ContactsSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClose,
    this.hintText = '搜索朋友',
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final String hintText;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(24, 4, 24, 8),
    child: Row(
      children: [
        Expanded(
          child: GlassSurface(
            radius: 28,
            child: Material(
              type: MaterialType.transparency,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => focusNode.unfocus(),
                  onTapOutside: (_) => focusNode.unfocus(),
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: hintText,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      maxWidth: 40,
                      minHeight: 48,
                      maxHeight: 48,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: SidebarActionIcon(
                            type: SidebarActionIconType.search,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空输入',
                            onPressed: controller.clear,
                            icon: const QuestionIcon(
                              type: QuestionIconType.close,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SettingsGlassAction(
          label: '关闭搜索',
          icon: Icons.close_rounded,
          iconWidget: const QuestionIcon(type: QuestionIconType.close),
          onPressed: onClose,
        ),
      ],
    ),
  );
}
