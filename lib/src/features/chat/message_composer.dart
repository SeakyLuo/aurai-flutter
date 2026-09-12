import 'package:flutter/material.dart';

import 'glass_surface.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.action,
    this.leading,
    this.attachments,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hintText;
  final Widget action;
  final Widget? leading;
  final Widget? attachments;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: BackdropGroup(
            child: GlassSurface(
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (attachments != null) attachments!,
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) {
                              final style = Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  );
                              final singleLinePadding = EdgeInsets.fromLTRB(
                                leading == null ? 16 : 48,
                                10,
                                48,
                                10,
                              );
                              final painter =
                                  TextPainter(
                                    text: TextSpan(
                                      text: value.text,
                                      style: style,
                                    ),
                                    textDirection: Directionality.of(context),
                                    textScaler: MediaQuery.textScalerOf(
                                      context,
                                    ),
                                    maxLines: 1,
                                  )..layout(
                                    maxWidth: constraints
                                        .deflate(singleLinePadding)
                                        .maxWidth,
                                  );
                              final multiline =
                                  value.text.contains('\n') ||
                                  painter.didExceedMaxLines;
                              painter.dispose();
                              return Stack(
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      enabled: enabled,
                                      style: style,
                                      minLines: 1,
                                      maxLines: 5,
                                      maxLength: maxLength,
                                      onChanged: onChanged,
                                      textInputAction: TextInputAction.newline,
                                      decoration: InputDecoration(
                                        hintText: hintText,
                                        hintStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        counterText: '',
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        contentPadding: multiline
                                            ? const EdgeInsets.fromLTRB(
                                                16,
                                                14,
                                                16,
                                                56,
                                              )
                                            : singleLinePadding,
                                      ),
                                    ),
                                  ),
                                  if (leading != null)
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      child: leading!,
                                    ),
                                  if (maxLength != null &&
                                      value.text.isNotEmpty &&
                                      multiline)
                                    Positioned(
                                      left: 16,
                                      bottom: 16,
                                      child: Text(
                                        '${value.text.characters.length}/$maxLength',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: action,
                                  ),
                                ],
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
