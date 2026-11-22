import 'attachment_actions.dart';
import 'unavailable_image.dart';
import 'question_icon.dart';
import 'settings_icon.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

import 'glass_surface.dart';

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
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() => _controlsVisible = false);
      unawaited(_setStatusBarVisible(false));
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      unawaited(_setStatusBarVisible(true));
    }
    _scheduleHide();
  }

  Future<void> _setStatusBarVisible(bool visible) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android when !kIsWeb:
        await const MethodChannel(
          'com.haiskynology.aurai/platform',
        ).invokeMethod<void>('setStatusBarVisible', visible);
      case TargetPlatform.iOS when !kIsWeb:
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [if (visible) SystemUiOverlay.top, SystemUiOverlay.bottom],
        );
      default:
        break;
    }
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
    if (_menuOpen) return;
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

  Future<void> _showActions(Offset position) => openAttachmentActions(
    context,
    position,
    image: widget.images[_index],
    sourceMessageId: _index == widget.initialIndex
        ? widget.initialOriginMessageId ?? widget.originMessageId
        : widget.originMessageId,
    allowAssetManagement: true,
    onTrashed: () {
      if (ModalRoute.of(context)!.isCurrent) Navigator.pop(context);
    },
  );

  @override
  void dispose() {
    _hideControls?.cancel();
    if (!_controlsVisible) unawaited(_setStatusBarVisible(true));
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
                    imageSize: index == widget.initialIndex
                        ? widget.imageSize
                        : null,
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
                                  Offset(box.size.width, box.size.height),
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
    required this.imageSize,
    required this.onTap,
  });
  final ImageProvider image;
  final Object heroTag;
  final bool heroEnabled;
  final Size? imageSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = imageSize;
    if (size == null) {
      return PhotoView(
        imageProvider: image,
        wantKeepAlive: true,
        onTapUp: (_, _, _) => onTap(),
        loadingBuilder: (_, _) => const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
        errorBuilder: (_, _, _) => const UnavailableImage(dark: true),
      );
    }

    // The first route frame needs the Hero even if the image stream is pending.
    return PhotoView.customChild(
      childSize: size,
      wantKeepAlive: true,
      heroAttributes: heroEnabled
          ? PhotoViewHeroAttributes(
              tag: heroTag,
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              flightShuttleBuilder: (_, animation, _, _, _) =>
                  imagePreviewFlight(image, animation),
            )
          : null,
      onTapUp: (_, _, _) => onTap(),
      child: Image(
        image: image,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const UnavailableImage(dark: true),
      ),
    );
  }
}
