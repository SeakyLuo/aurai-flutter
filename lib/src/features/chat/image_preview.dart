import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'unavailable_image.dart';
import 'chat_controller.dart';
import 'image_action_scope.dart';
import 'image_forward_page.dart';
import 'home_navigation.dart';
import 'question_icon.dart';
import 'settings_icon.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import 'glass_surface.dart';
import 'image_actions_menu.dart';
import '../../platform/preview_image_actions.dart';

Future<Size> loadPreviewImageSize(
  ImageProvider image,
  BuildContext context,
) async {
  final stream = image.resolve(createLocalImageConfiguration(context));
  final result = Completer<Size>();
  final listener = ImageStreamListener(
    (info, _) {
      result.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
      info.dispose();
    },
    onError: (Object error, StackTrace? stack) =>
        result.completeError(error, stack),
  );
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

Widget imagePreviewFlight(ImageProvider image, Animation<double> animation) =>
    AnimatedBuilder(
      animation: animation,
      builder: (_, child) => ClipRRect(
        borderRadius: BorderRadius.circular(16 * (1 - animation.value)),
        child: child,
      ),
      child: Image(
        image: image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const UnavailableImage(dark: true),
      ),
    );

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.images,
    this.originMessageId,
    this.initialOriginMessageId,
    required this.initialIndex,
    required this.heroTag,
    required this.imageSize,
    this.onActions,
  });
  final List<ImageProvider> images;
  final String? originMessageId;
  final String? initialOriginMessageId;
  final int initialIndex;
  final Object heroTag;
  final Size imageSize;
  final Future<void> Function(BuildContext, int, Offset)? onActions;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  bool _exporting = false;
  bool _controlsVisible = true;
  bool _menuOpen = false;
  int _pointers = 0;
  Timer? _hideControls;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideControls?.cancel();
    if (_menuOpen || _pointers > 0) return;
    _hideControls = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers++;
    _showControls();
  }

  void _pointerEnd(PointerEvent event) {
    _pointers--;
    _scheduleHide();
  }

  Future<void> _openActions(Offset position) async {
    if (_menuOpen || _exporting) return;
    _menuOpen = true;
    _showControls();
    try {
      if (widget.onActions != null) {
        await widget.onActions!(context, _index, position);
      } else {
        await _showActions(position);
      }
    } finally {
      _menuOpen = false;
      if (mounted) _scheduleHide();
    }
  }

  Future<void> _showActions(Offset position) async {
    if (_exporting) return;
    final image = widget.images[_index];
    final originMessageId = _index == widget.initialIndex
        ? widget.initialOriginMessageId ?? widget.originMessageId
        : widget.originMessageId;
    if (image is FileImage && !await image.file.exists()) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          const SnackBar(content: Text('图片文件已丢失，无法保存或转发')),
          kind: ToastKind.error,
        );
      return;
    }
    if (!mounted) return;
    final controller = ImageActionScope.of(context);
    ({String conversationId, String messageId})? origin;
    try {
      if (originMessageId != null || image is FileImage) {
        origin = await controller.imageOrigin(
          messageId: originMessageId,
          path: image is FileImage ? image.file.path : null,
        );
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('无法读取图片来源：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
    }
    if (!mounted) return;
    final action = await showImageActionsMenu(
      context,
      position,
      canLocate: origin != null,
    );
    if (action == null || !mounted || _exporting) return;
    if (action == 'share') {
      final sent = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ImageForwardPage(controller: controller, image: image),
        ),
      );
      if (sent == true && mounted)
        ScaffoldMessenger.of(context).showToast(
          const SnackBar(content: Text('已转发')),
          kind: ToastKind.success,
        );
      return;
    }
    if (action == 'locate') {
      final source = origin!;
      try {
        await openHomeConversation(
          context,
          controller,
          source.conversationId,
          messageId: source.messageId,
        );
      } on Object catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text('无法定位原消息，可能已被删除：${errorMessage(error)}')),
            kind: ToastKind.error,
          );
      }
      return;
    }
    _exporting = true;
    try {
      final saved = await PreviewImageActions.perform(image, action);
      if (mounted && action == 'save' && saved) {
        ScaffoldMessenger.of(context).showToast(
          const SnackBar(content: Text('图片已保存到应用目录')),
          kind: ToastKind.success,
        );
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(
            content: Text(
              action == 'save'
                  ? '图片保存失败，请重试：${errorMessage(error)}'
                  : '无法转发图片，请重试：${errorMessage(error)}',
            ),
          ),
          kind: ToastKind.error,
        );
    } finally {
      _exporting = false;
    }
  }

  @override
  void dispose() {
    _hideControls?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Listener(
      onPointerDown: _pointerDown,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      onPointerHover: (_) => _showControls(),
      onPointerSignal: (_) => _showControls(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        onLongPressStart: (details) => _openActions(details.globalPosition),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: false,
              child: PhotoViewGestureDetectorScope(
                axis: Axis.horizontal,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: widget.images.length,
                  onPageChanged: (index) => setState(() {
                    _index = index;
                  }),
                  itemBuilder: (context, index) => _PreviewPage(
                    key: ValueKey(index),
                    image: widget.images[index],
                    heroTag: widget.heroTag,
                    heroEnabled:
                        index == widget.initialIndex && index == _index,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _control(
                          label: '关闭预览',
                          icon: const QuestionIcon(
                            type: QuestionIconType.close,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Builder(
                          builder: (buttonContext) => _control(
                            label: '更多',
                            icon: const SettingsIcon(
                              type: SettingsIconType.more,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              final box =
                                  buttonContext.findRenderObject()!
                                      as RenderBox;
                              _openActions(
                                box.localToGlobal(
                                  Offset(box.size.width, box.size.height + 8),
                                ),
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
          ],
        ),
      ),
    ),
  );

  Widget _control({
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
  }) => GlassSurface(
    dark: true,
    tintOpacity: .6,
    radius: 24,
    shadowOpacity: .8,
    child: RoundAction(
      icon: Icons.more_vert,
      iconWidget: icon,
      label: label,
      onPressed: onPressed,
    ),
  );
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    super.key,
    required this.image,
    required this.heroTag,
    required this.heroEnabled,
    required this.onTap,
  });
  final ImageProvider image;
  final Object heroTag;
  final bool heroEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PhotoView(
    imageProvider: image,
    wantKeepAlive: true,
    heroAttributes: heroEnabled
        ? PhotoViewHeroAttributes(
            tag: heroTag,
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            flightShuttleBuilder:
                (flightContext, animation, direction, from, to) =>
                    imagePreviewFlight(image, animation),
          )
        : null,
    onTapUp: (_, _, _) => onTap(),
    loadingBuilder: (_, _) =>
        const Center(child: CircularProgressIndicator(color: Colors.white70)),
    errorBuilder: (_, _, _) => const UnavailableImage(dark: true),
  );
}
