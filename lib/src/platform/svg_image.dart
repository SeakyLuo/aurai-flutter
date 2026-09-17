import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mime/mime.dart';

String? imageBytesMime(List<int> bytes) {
  final mime = lookupMimeType('', headerBytes: bytes);
  if (mime != null && mime.startsWith('image/')) return mime;
  if (RegExp(
    r'<svg(?:\s|>)',
  ).hasMatch(utf8.decode(bytes, allowMalformed: true))) {
    return 'image/svg+xml';
  }
  return mime;
}

Future<void> validateSvg(Uint8List bytes) async {
  final picture = await vg.loadPicture(SvgBytesLoader(bytes), null);
  try {
    if (picture.size.isEmpty || !picture.size.isFinite) {
      throw const FormatException('SVG 缺少有效的画布尺寸');
    }
  } finally {
    picture.picture.dispose();
  }
}

/// Keep the original vector file. Rasterize only for image decoders and vision APIs.
Future<Uint8List> svgToPng(Uint8List bytes, {int maxDimension = 2048}) async {
  final picture = await vg.loadPicture(SvgBytesLoader(bytes), null);
  try {
    final size = picture.size;
    if (size.isEmpty || !size.isFinite) {
      throw const FormatException('SVG 缺少有效的画布尺寸');
    }
    final scale = maxDimension / math.max(size.width, size.height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    canvas.drawPicture(picture.picture);
    final scaled = recorder.endRecording();
    try {
      final image = await scaled.toImage(
        math.max(1, (size.width * scale).round()),
        math.max(1, (size.height * scale).round()),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      scaled.dispose();
    }
  } finally {
    picture.picture.dispose();
  }
}

Future<({Uint8List bytes, String mimeType})> readVisionImage(
  File file,
  String mimeType,
) async {
  final bytes = await file.readAsBytes();
  if (mimeType == 'image/svg+xml') {
    return (bytes: await svgToPng(bytes), mimeType: 'image/png');
  }
  return (bytes: bytes, mimeType: mimeType);
}

FileImage localImageProvider(String path) => path.toLowerCase().endsWith('.svg')
    ? SvgFileImage(File(path))
    : FileImage(File(path));

/// A file-backed provider lets preview, forwarding and export retain the SVG bytes.
class SvgFileImage extends FileImage {
  const SvgFileImage(super.file);

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _codec(key, (buffer) => decode(buffer)),
        scale: key.scale,
        debugLabel: key.file.path,
      );

  Future<ui.Codec> _codec(
    FileImage key,
    Future<ui.Codec> Function(ui.ImmutableBuffer) decode,
  ) async {
    final png = await svgToPng(await key.file.readAsBytes());
    return decode(await ui.ImmutableBuffer.fromUint8List(png));
  }
}
