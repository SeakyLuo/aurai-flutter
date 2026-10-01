import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

class ImageGenerationSkeleton extends StatefulWidget {
  const ImageGenerationSkeleton({
    super.key,
    required this.title,
    required this.aspectRatio,
    this.count = 1,
    this.referenceImage,
  });

  final String title;
  final String aspectRatio;
  final int count;
  final String? referenceImage;

  @override
  State<ImageGenerationSkeleton> createState() =>
      _ImageGenerationSkeletonState();
}

class _ImageGenerationSkeletonState extends State<ImageGenerationSkeleton>
    with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Timer _timer;
  final Stopwatch _elapsed = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _elapsed.stop();
    _shimmer.dispose();
    super.dispose();
  }

  double get _ratio => switch (widget.aspectRatio) {
    '16:9' => 16 / 9,
    '9:16' => 9 / 16,
    '4:3' => 4 / 3,
    '3:4' => 3 / 4,
    _ => 1,
  };

  String get _elapsedLabel {
    final seconds = _elapsed.elapsed.inSeconds;
    if (seconds < 60) return '$seconds 秒';
    return '${seconds ~/ 60} 分 ${seconds % 60} 秒';
  }

  ImageProvider get _referenceProvider {
    final source = widget.referenceImage!;
    final uri = Uri.parse(source);
    return switch (uri.scheme) {
      'http' || 'https' => NetworkImage(source),
      'data' => MemoryImage(uri.data!.contentAsBytes()),
      _ => FileImage(File(source)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxHeight = 280.0;
    final singleWidth = switch (widget.aspectRatio) {
      '16:9' || '4:3' => 280.0,
      '9:16' || '3:4' => maxHeight * _ratio,
      _ => 220.0,
    };
    final base = colors.onSurface.withValues(alpha: .055);
    final highlight = colors.onSurface.withValues(alpha: .12);
    final multiple = widget.count > 1;

    Widget tile(int index) => ClipRRect(
      borderRadius: BorderRadius.circular(multiple ? 16 : 20),
      child: SizedBox(
        width: multiple ? 132 : singleWidth,
        child: AspectRatio(
          aspectRatio: _ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.referenceImage != null)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Image(
                    image: _referenceProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: base),
                  ),
                )
              else
                ColoredBox(color: base),
              if (widget.referenceImage != null)
                ColoredBox(color: colors.surface.withValues(alpha: .32)),
              AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-3 + _shimmer.value * 6, 0),
                      end: Alignment(-1 + _shimmer.value * 6, 0),
                      colors: [
                        Colors.transparent,
                        highlight,
                        Colors.transparent,
                      ],
                      stops: const [0, .5, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: multiple ? 7 : 12,
                right: multiple ? 7 : 12,
                bottom: multiple ? 7 : 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(multiple ? 11 : 14),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: multiple ? 8 : 12,
                      vertical: multiple ? 6 : 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            multiple
                                ? '正在生成 ${index + 1}/${widget.count}'
                                : widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: multiple ? 11 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: multiple ? 4 : 10),
                        Text(
                          _elapsedLabel,
                          style: TextStyle(
                            fontSize: multiple ? 10 : 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: '${widget.title}，共 ${widget.count} 张，已等待 $_elapsedLabel',
      child: Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < widget.count; index++) tile(index),
          ],
        ),
      ),
    );
  }
}
