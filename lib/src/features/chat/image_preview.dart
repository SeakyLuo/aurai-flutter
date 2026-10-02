import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'unavailable_image.dart';
import 'chat_controller.dart';
import 'image_action_scope.dart';
import 'image_forward_page.dart';
import 'home_navigation.dart';
import 'dart:async';
import 'dart:math' as math;

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
  });
  final List<ImageProvider> images;
  final String? originMessageId;
  final String? initialOriginMessageId;
  final int initialIndex;
  final Object heroTag;
  final Size imageSize;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  bool _exporting = false;

  Future<void> _showActions(LongPressStartDetails details) async {
    if (_exporting) return;
    final image = widget.images[_index];
    final originMessageId = _index == widget.initialIndex
        ? widget.initialOriginMessageId ?? widget.originMessageId
        : widget.originMessageId;
    if (image is FileImage && !await image.file.exists()) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('图片文件已丢失，无法保存或转发')));
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
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法读取图片来源：${errorMessage(error)}')),
        );
    }
    if (!mounted) return;
    final action = await showImageActionsMenu(
      context,
      details.globalPosition,
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
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('已转发')));
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
          ScaffoldMessenger.of(context).showGlassSnackBar(
            SnackBar(content: Text('无法定位原消息，可能已被删除：${errorMessage(error)}')),
          );
      }
      return;
    }
    _exporting = true;
    try {
      final saved = await PreviewImageActions.perform(image, action);
      if (mounted && action == 'save' && saved) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('图片已保存到应用目录')));
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text(
              action == 'save'
                  ? '图片保存失败，请重试：${errorMessage(error)}'
                  : '无法转发图片，请重试：${errorMessage(error)}',
            ),
          ),
        );
    } finally {
      _exporting = false;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      onLongPressStart: _showActions,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            top: false,
            child: PhotoViewGestureDetectorScope(
              axis: Axis.horizontal,
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.images.length,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _zoomed = false;
                }),
                itemBuilder: (context, index) => _PreviewPage(
                  key: ValueKey(index),
                  image: widget.images[index],
                  initialSize: index == widget.initialIndex
                      ? widget.imageSize
                      : null,
                  heroTag: widget.heroTag,
                  heroEnabled: index == widget.initialIndex && index == _index,
                  onZoomChanged: (zoomed) {
                    if (index == _index && zoomed != _zoomed) {
                      setState(() => _zoomed = zoomed);
                    }
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: GlassSurface(
                dark: true,
                tintOpacity: .6,
                radius: 24,
                shadowOpacity: .8,
                child: RoundAction(
                  icon: Icons.close_rounded,
                  iconWidget: const Icon(
                    Icons.close_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                  label: '关闭预览',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage({
    super.key,
    required this.image,
    required this.initialSize,
    required this.heroTag,
    required this.heroEnabled,
    required this.onZoomChanged,
  });
  final ImageProvider image;
  final Size? initialSize;
  final Object heroTag;
  final bool heroEnabled;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  final _photoController = PhotoViewController();
  late final StreamSubscription<PhotoViewControllerValue> _scaleSubscription;
  double _fitScale = 1;
  late final Future<Size?> _size = _load();
  bool _zoomed = false;

  Future<Size?> _load() async {
    if (widget.initialSize != null) return widget.initialSize;
    try {
      return await loadPreviewImageSize(widget.image, context);
    } on Object {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _scaleSubscription = _photoController.outputStateStream.listen(_onScale);
  }

  void _onScale(PhotoViewControllerValue value) {
    final scale = value.scale;
    if (scale == null) return;
    final zoomed = scale > _fitScale * 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  @override
  void dispose() {
    _scaleSubscription.cancel();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Size?>(
    future: _size,
    initialData: widget.initialSize,
    builder: (context, snapshot) {
      final size = snapshot.data;
      if (size == null) {
        return snapshot.connectionState == ConnectionState.done
            ? const UnavailableImage(dark: true)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final fitted = applyBoxFit(
            BoxFit.contain,
            size,
            constraints.biggest,
          ).destination;
          _fitScale = fitted.width / size.width;
          final coverScale = math.max(
            constraints.maxWidth / size.width,
            constraints.maxHeight / size.height,
          );
          final nativeScale = 1 / MediaQuery.devicePixelRatioOf(context);
          return PhotoView.customChild(
            controller: _photoController,
            childSize: size,
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: math.max(
              math.max(coverScale * 2, nativeScale * 2),
              _fitScale * 3,
            ),
            filterQuality: FilterQuality.medium,
            onTapUp: (_, _, _) => Navigator.pop(context),
            child: RepaintBoundary(
              child: HeroMode(
                enabled: widget.heroEnabled,
                child: Hero(
                  tag: widget.heroTag,
                  createRectTween: (begin, end) =>
                      RectTween(begin: begin, end: end),
                  flightShuttleBuilder:
                      (flightContext, animation, direction, from, to) =>
                          imagePreviewFlight(widget.image, animation),
                  child: SizedBox.fromSize(
                    size: size,
                    child: Image(
                      image: widget.image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) =>
                          const UnavailableImage(dark: true),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
