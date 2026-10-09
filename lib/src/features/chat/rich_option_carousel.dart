import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../agent/ask_user_tool.dart';
import '../../app/ui_action.dart';
import '../../storage/selection_option_content.dart';
import '../../platform/svg_image.dart';
import 'image_action_scope.dart';
import 'message_content_preview.dart';
import 'pinned_message_page.dart';
import 'question_option_appearance.dart';
import 'selection_option_prefix.dart';
import 'question_sheet.dart';
import 'settings_icon.dart';
import 'unavailable_image.dart';
import 'file_type_icon.dart';

/// Only the header selects. Content opens the original component and retains
/// its native permissions, media controls and persistent miniapp session.
class RichOptionCarousel extends StatefulWidget {
  const RichOptionCarousel({
    super.key,
    required this.options,
    required this.selected,
    required this.multiple,
    required this.onSelect,
    this.maximum = 25,
    this.captions,
    this.numbers,
    this.optionPrefix,
  });
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final bool multiple;
  final ValueChanged<int>? onSelect;
  final int maximum;
  final List<String>? captions;
  final List<int>? numbers;
  final String? optionPrefix;

  @override
  State<RichOptionCarousel> createState() => _RichOptionCarouselState();
}

class _RichOptionCarouselState extends State<RichOptionCarousel> {
  final _scroll = ScrollController();
  Map<String, SelectionOptionContent> _content = {};
  Set<String>? _loadedIds;
  int _request = 0, _index = 0;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RichOptionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final ids = widget.options
        .map((o) => o.messageId)
        .whereType<String>()
        .toSet();
    if (_loadedIds != null &&
        ids.length == _loadedIds!.length &&
        ids.containsAll(_loadedIds!))
      return;
    _loadedIds = ids;
    _content = {};
    _loading = true;
    final request = ++_request;
    final controller = ImageActionScope.of(context);
    // Defer the UI error boundary until after the current build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || request != _request) return;
      await runUiAction(context, () async {
        final root = await getApplicationSupportDirectory();
        final content = await loadSelectionOptionContent(
          controller.groupStore.database,
          '${root.path}/message_images',
          ids,
        );
        if (mounted && request == _request) setState(() => _content = content);
      });
      if (mounted && request == _request) setState(() => _loading = false);
    });
  }

  Future<void> _open(String id) => runUiAction(context, () async {
    final controller = ImageActionScope.of(context);
    final root = await getApplicationSupportDirectory();
    final fresh = await loadSelectionOptionContent(
      controller.groupStore.database,
      '${root.path}/message_images',
      {id},
    );
    final content = fresh[id];
    if (content == null) throw StateError('选项内容已删除、撤回或不可见');
    if (!mounted) return;
    await showQuestionSheet(
      context,
      child: PinnedMessagePage(
        controller: controller,
        conversationId: content.conversationId,
        messageId: id,
        sheet: true,
        pinned: false,
        interactiveReference: content.message.interactive != null,
      ),
    );
  }).then((_) {});

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _preview(UserQuestionOption option) {
    final id = option.messageId;
    if (id == null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            option.content,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    final message = _content[id]?.message;
    if (message == null)
      return Center(
        child: _loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('内容不可用'),
      );
    final imagePath =
        message.images.firstOrNull?.path ?? message.miniappShare?.imagePath;
    if (imagePath != null)
      return Image(
        image: ResizeImage.resizeIfNeeded(
          480,
          null,
          localImageProvider(imagePath),
        ),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const UnavailableImage(),
      );
    if (message.html?.preview != null)
      return Image.memory(
        message.html!.preview!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const UnavailableImage(),
      );
    if (message.files.isNotEmpty) {
      final file = message.files.first;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 36,
                child: FittedBox(child: FileTypeIcon(file: file)),
              ),
              const SizedBox(height: 10),
              Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: MessageContentPreview(
            text: message.text,
            files: message.files,
            htmlTitle: message.html?.title ?? message.miniappShare?.title,
            interactiveTitle: message.interactive?.title,
            interactiveVote: message.interactive?.isVote ?? false,
            maxLines: 4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(180.0, constraints.maxWidth * .78);
      final colors = Theme.of(context).colorScheme;
      final accent = QuestionOptionAppearance.accent(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: side,
            child: NotificationListener<ScrollNotification>(
              onNotification: (event) {
                if (event.metrics.axis == Axis.horizontal) {
                  final index = event.metrics.pixels > 0 && event.metrics.atEdge
                      ? widget.options.length - 1
                      : (event.metrics.pixels / (side + 10)).round().clamp(
                          0,
                          widget.options.length - 1,
                        );
                  if (index != _index) setState(() => _index = index);
                }
                return false;
              },
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final selected = widget.selected.contains(index);
                  final enabled =
                      widget.onSelect != null &&
                      (!widget.multiple ||
                          selected ||
                          widget.selected.length < widget.maximum);
                  return SizedBox.square(
                    dimension: side,
                    child: Material(
                      color: colors.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected ? accent : colors.outlineVariant,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Semantics(
                            label:
                                '选择选项 ${widget.numbers?[index] ?? index + 1}：${option.content}',
                            selected: selected,
                            checked: selected,
                            inMutuallyExclusiveGroup: !widget.multiple,
                            child: InkWell(
                              onTap: enabled
                                  ? () => widget.onSelect!(index)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    if (widget.optionPrefix != null)
                                      SelectionOptionPrefix(
                                        number:
                                            widget.numbers?[index] ?? index + 1,
                                        style: widget.optionPrefix!,
                                        selected: selected,
                                      )
                                    else
                                      Text(
                                        '${widget.numbers?[index] ?? index + 1}',
                                        style: TextStyle(
                                          color: selected
                                              ? accent
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        option.content ==
                                                '选项 ${widget.numbers?[index] ?? index + 1}'
                                            ? ''
                                            : option.content,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? QuestionOptionAppearance.selectedIndicator(
                                                context,
                                              )
                                            : null,
                                        borderRadius: BorderRadius.circular(
                                          widget.multiple ? 6 : 11,
                                        ),
                                        border: Border.all(
                                          color: selected
                                              ? accent
                                              : colors.outlineVariant,
                                        ),
                                      ),
                                      child: selected
                                          ? Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: FittedBox(
                                                child: SettingsIcon(
                                                  type: SettingsIconType.check,
                                                  color: accent,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: option.messageId == null
                                  ? (enabled
                                        ? () => widget.onSelect!(index)
                                        : null)
                                  : () => _open(option.messageId!),
                              child: IgnorePointer(
                                child: SizedBox.expand(child: _preview(option)),
                              ),
                            ),
                          ),
                          if (widget.captions case final captions?)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Text(
                                captions[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${math.min(_index + 1, widget.options.length)} / ${widget.options.length}',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const Spacer(),
              if (widget.onSelect != null || widget.selected.isNotEmpty)
                Text(
                  '已选 ${widget.selected.length} 项',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
