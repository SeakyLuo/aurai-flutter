import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/message_image.dart';
import 'glass_surface.dart';

Future<Size> loadPreviewImageSize(
  MessageImage image,
  BuildContext context,
) async {
  final stream = FileImage(
    File(image.path),
  ).resolve(createLocalImageConfiguration(context));
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

Widget imagePreviewFlight(MessageImage image, Animation<double> animation) =>
    AnimatedBuilder(
      animation: animation,
      builder: (_, child) => ClipRRect(
        borderRadius: BorderRadius.circular(16 * (1 - animation.value)),
        child: child,
      ),
      child: Image.file(File(image.path), fit: BoxFit.cover),
    );

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.heroTag,
    required this.imageSize,
  });
  final List<MessageImage> images;
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
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
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: GlassSurface(
              dark: true,
              radius: 24,
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
  final MessageImage image;
  final Size? initialSize;
  final Object heroTag;
  final bool heroEnabled;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  final _transform = TransformationController();
  late final Future<Size?> _size = _load();
  bool _zoomed = false;

  Future<Size?> _load() async {
    if (widget.initialSize != null) return widget.initialSize;
    try {
      return await loadPreviewImageSize(widget.image, context);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片无法打开，请重试')));
      }
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  @override
  void dispose() {
    _transform.dispose();
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
            ? const SizedBox.shrink()
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
          return InteractiveViewer(
            transformationController: _transform,
            panEnabled: _zoomed,
            minScale: 1,
            maxScale: 5,
            child: SizedBox.expand(
              child: Center(
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
                      size: fitted,
                      child: Image.file(
                        File(widget.image.path),
                        fit: BoxFit.contain,
                      ),
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
