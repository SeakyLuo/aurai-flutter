import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'image_preview.dart';
import 'attachment_action_icon.dart';

class ReplyImageGalleryBuilder extends MarkdownElementBuilder {
  ReplyImageGalleryBuilder(this.onOpenSource);
  final ValueChanged<String> onOpenSource;
  @override
  bool isBlockElement() => true;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => ReplyImageGallery(
    images: element.children!
        .cast<md.Element>()
        .map(
          (e) => (
            url: e.attributes['src']!,
            title: e.attributes['alt'] ?? '',
            source: e.attributes['source'],
          ),
        )
        .toList(),
    onOpenSource: onOpenSource,
  );
}

typedef ReplyImage = ({String url, String title, String? source});

class ReplyImageGallery extends StatelessWidget {
  const ReplyImageGallery({
    super.key,
    required this.images,
    required this.onOpenSource,
  });
  final List<ReplyImage> images;
  final ValueChanged<String> onOpenSource;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = images.length == 1
          ? constraints.maxWidth
          : constraints.maxWidth * .72;
      final height = (constraints.maxWidth * .58).clamp(160.0, 260.0);
      return SizedBox(
        height: height + 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => SizedBox(
            width: width,
            child: _ReplyImageCard(
              key: ValueKey(images[index].url),
              images: images,
              index: index,
              height: height,
              onOpenSource: onOpenSource,
            ),
          ),
        ),
      );
    },
  );
}

class _ReplyImageCard extends StatefulWidget {
  const _ReplyImageCard({
    super.key,
    required this.images,
    required this.index,
    required this.height,
    required this.onOpenSource,
  });
  final List<ReplyImage> images;
  final int index;
  final double height;
  final ValueChanged<String> onOpenSource;
  @override
  State<_ReplyImageCard> createState() => _ReplyImageCardState();
}

class _ReplyImageCardState extends State<_ReplyImageCard> {
  final _hero = Object();
  bool _opening = false;
  bool _errorReported = false;
  int _retry = 0;
  ReplyImage get _image => widget.images[widget.index];
  NetworkImage get _provider => NetworkImage(_image.url);

  void _notice() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片加载失败，点按图片重试')));
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      if (_errorReported) {
        await _provider.evict();
        if (!mounted) return;
        setState(() {
          _errorReported = false;
          _retry++;
        });
      }
      final size = await loadPreviewImageSize(_provider, context);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, animation, secondaryAnimation) => ImagePreview(
            images: [
              for (final image in widget.images) NetworkImage(image.url),
            ],
            initialIndex: widget.index,
            heroTag: _hero,
            imageSize: size,
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
    } on Object {
      if (mounted) _notice();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = Uri.tryParse(_image.source ?? '');
    final hasSource =
        source != null &&
        {'https', 'http'}.contains(source.scheme) &&
        source.host.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: _image.title.isEmpty ? '查看参考图片' : _image.title,
          child: GestureDetector(
            onTap: _open,
            child: Hero(
              tag: _hero,
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              flightShuttleBuilder: (_, animation, direction, from, to) =>
                  imagePreviewFlight(_provider, animation),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: widget.height,
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Image(
                      image: _provider,
                      key: ValueKey(_retry),
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, sync) =>
                          frame == null
                          ? const Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : child,
                      errorBuilder: (context, error, stack) {
                        if (!_errorReported) {
                          _errorReported = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _notice();
                          });
                        }
                        return const Center(
                          child: AttachmentActionIcon(
                            type: AttachmentActionIconType.gallery,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasSource)
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => widget.onOpenSource(_image.source!),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  source.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
