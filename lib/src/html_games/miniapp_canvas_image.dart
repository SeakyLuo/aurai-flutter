import 'dart:convert';
import 'dart:ui' as ui;

import '../domain/tool_models.dart';

/// Render the public canvas projection as a real model image, without a WebView.
/// Coordinates are normalized; brush widths use the canvas's logical pixel size.
Future<List<ToolAttachment>> miniappCanvasAttachments(
  Map<String, Object?> output,
) async {
  final state = output['state'] as Map;
  final projection = state['canvas'];
  if (projection == null) return const [];
  final drawing = projection as Map;
  final width = drawing['width'] as int;
  final height = drawing['height'] as int;
  if (width <= 0 || height <= 0) throw ArgumentError('画布尺寸必须为正整数');
  final strokes = drawing['strokes'] as List;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(_color(drawing['background'] as String), ui.BlendMode.src);
  for (final raw in strokes) {
    final stroke = raw as Map;
    final points = stroke['points'] as List;
    if (points.isEmpty) throw ArgumentError('笔画缺少坐标');
    final brushWidth = (stroke['width'] as num).toDouble();
    if (!brushWidth.isFinite || brushWidth <= 0) {
      throw ArgumentError('画笔粗细必须为有限正数');
    }
    final paint = ui.Paint()
      ..color = _color(stroke['color'] as String)
      ..strokeWidth = brushWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;
    final path = ui.Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i] as List;
      if (point.length != 2) throw ArgumentError('笔画坐标必须为 [x,y]');
      final x = (point[0] as num).toDouble();
      final y = (point[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
        throw ArgumentError('笔画坐标必须在 0 到 1 之间');
      }
      i == 0
          ? path.moveTo(x * width, y * height)
          : path.lineTo(x * width, y * height);
    }
    if (points.length == 1) {
      final point = points.single as List;
      canvas.drawCircle(
        ui.Offset(
          (point[0] as num).toDouble() * width,
          (point[1] as num).toDouble() * height,
        ),
        brushWidth / 2,
        paint..style = ui.PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(width, height);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      state['canvas'] = {
        'width': width,
        'height': height,
        'strokeCount': strokes.length,
        'contentProvided': true,
      };
      return [
        ToolAttachment(
          type: ToolAttachmentType.image,
          mimeType: 'image/png',
          base64Data: base64Encode(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          ),
          detail: 'high',
        ),
      ];
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

ui.Color _color(String value) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw ArgumentError('画笔颜色必须为六位十六进制颜色');
  }
  return ui.Color(0xff000000 | int.parse(value.substring(1), radix: 16));
}
