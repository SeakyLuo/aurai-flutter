import '../../app/glass_notice.dart';
import '../../platform/svg_image.dart';
import '../../domain/error_message.dart';
import 'unavailable_image.dart';
import 'image_action_scope.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/message_image.dart';
import 'image_preview.dart';
export 'attachment_source_menu.dart';

/// Keep message thumbnails compact while retaining every image in the viewer.
class MessageImageGrid extends StatelessWidget {
  const MessageImageGrid({super.key, required this.images});

  final List<MessageImage> images;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = images.length > 4 ? 4 : images.length;
      final columns = count == 3
          ? 3
          : count == 1
          ? 1
          : 2;
      final width = constraints.maxWidth.clamp(0.0, count == 1 ? 260.0 : 320.0);
      const gap = 8.0;
      final size = (width - gap * (columns - 1)) / columns;
      return SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var start = 0; start < count; start += columns) ...[
              if (start > 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: gap),
                    Stack(
                      children: [
                        ImageAttachment(
                          image: images[i],
                          gallery: images,
                          size: size,
                        ),
                        if (i == 3 && images.length > 4)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '+${images.length - 4}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

class DraftImageAttachments extends StatelessWidget {
  const DraftImageAttachments({
    super.key,
    required this.images,
    required this.onRemove,
  });

  final List<MessageImage> images;
  final ValueChanged<MessageImage>? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(6),
      itemCount: images.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) => SizedBox(
        width: 80,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: ImageAttachment(
                image: images[index],
                gallery: images,
                size: 80,
                borderRadius: 20,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: '移除图片 ${index + 1}',
                onPressed: onRemove == null
                    ? null
                    : () => onRemove!(images[index]),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.topRight,
                style: IconButton.styleFrom(overlayColor: Colors.transparent),
                icon: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xff333333),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ImageAttachment extends StatefulWidget {
  const ImageAttachment({
    super.key,
    required this.image,
    required this.gallery,
    required this.size,
    this.height,
    this.borderRadius = 16,
    this.onOpen,
    this.sourceMessageId,
  });
  final MessageImage image;
  final List<MessageImage> gallery;
  final double size;
  final double? height;
  final double borderRadius;
  final VoidCallback? onOpen;
  final String? sourceMessageId;

  @override
  State<ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<ImageAttachment> {
  final _heroTag = Object();
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      final Size imageSize;
      try {
        if (!await File(widget.image.path).exists()) {
          if (mounted)
            ScaffoldMessenger.of(context).showToast(
              const SnackBar(content: Text('图片文件已丢失，无法打开')),
              kind: ToastKind.error,
            );
          return;
        }
        if (!mounted) return;
        imageSize = await loadPreviewImageSize(
          localImageProvider(widget.image.path),
          context,
        );
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text('图片无法打开，请重试：${errorMessage(error)}')),
            kind: ToastKind.error,
          );
        }
        return;
      }
      if (!mounted) return;
      widget.onOpen?.call();
      final originMessageId = ImageMessageScope.of(context);
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, animation, secondaryAnimation) => ImagePreview(
            originMessageId: originMessageId,
            initialOriginMessageId: widget.sourceMessageId,
            images: [
              for (final image in widget.gallery)
                localImageProvider(image.path),
            ],
            initialIndex: widget.gallery.indexOf(widget.image),
            heroTag: _heroTag,
            imageSize: imageSize,
          ),
          transitionsBuilder: (_, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: animation.drive(
                  CurveTween(curve: Curves.easeInOutCubic),
                ),
                child: child,
              ),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看图片',
    child: Hero(
      tag: _heroTag,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: (flightContext, animation, direction, from, to) =>
          imagePreviewFlight(localImageProvider(widget.image.path), animation),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: _open,
            child: Image(
              image: ResizeImage.resizeIfNeeded(
                (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
                null,
                localImageProvider(widget.image.path),
              ),
              width: widget.size,
              height: widget.height ?? widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => SizedBox(
                width: widget.size,
                height: widget.height ?? widget.size,
                child: const UnavailableImage(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
