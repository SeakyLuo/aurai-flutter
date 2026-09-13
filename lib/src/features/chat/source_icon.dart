import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/source_reference.dart';
import 'file_tool_icon.dart';

class SourceIcon extends StatefulWidget {
  const SourceIcon({super.key, required this.source, this.size = 16});
  final SourceReference source;
  final double size;

  @override
  State<SourceIcon> createState() => _SourceIconState();
}

class _SourceIconState extends State<SourceIcon> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SourceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url) _resolve();
  }

  void _resolve() {
    if (widget.source.isFile) {
      if (_listener != null) _stream!.removeListener(_listener!);
      _listener = null;
      _stream = null;
      _image?.dispose();
      _image = null;
      _generation++;
      return;
    }
    final stream = NetworkImage(
      Uri.parse(widget.source.url).resolve('/favicon.ico').toString(),
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    if (_listener != null) _stream!.removeListener(_listener!);
    _image?.dispose();
    _image = null;
    _stream = stream;
    final generation = ++_generation;
    _listener = ImageStreamListener(
      (image, synchronousCall) => _received(image, generation),
      onError: (Object error, StackTrace? stack) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _image?.dispose();
          _image = null;
        });
      },
    );
    stream.addListener(_listener!);
  }

  Future<void> _received(ImageInfo image, int generation) async {
    final visible = await _hasArtwork(image.image);
    if (!mounted || generation != _generation) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = visible ? image : null;
    });
    if (!visible) image.dispose();
  }

  // A successful download can still be a transparent or plain-white placeholder.
  Future<bool> _hasArtwork(ui.Image image) async {
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (pixels == null) return false;
    final bytes = pixels.buffer.asUint8List();
    final stepX = (image.width ~/ 32).clamp(1, image.width);
    final stepY = (image.height ~/ 32).clamp(1, image.height);
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final offset = (y * image.width + x) * 4;
        if (bytes[offset + 3] > 32 &&
            (bytes[offset] < 235 ||
                bytes[offset + 1] < 235 ||
                bytes[offset + 2] < 235)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    if (_listener != null) _stream!.removeListener(_listener!);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipOval(
      child: widget.source.isFile
          ? SizedBox.square(
              dimension: widget.size,
              child: const FittedBox(
                child: FileToolIcon(type: FileToolIconType.document),
              ),
            )
          : _image == null
          ? CustomPaint(
              size: Size.square(widget.size),
              painter: _GlobePainter(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : RawImage(
              image: _image!.image,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
    ),
  );
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 12), 9, paint);
    canvas.drawOval(const Rect.fromLTRB(8, 3, 16, 21), paint);
    canvas.drawLine(const Offset(3, 12), const Offset(21, 12), paint);
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => oldDelegate.color != color;
}
