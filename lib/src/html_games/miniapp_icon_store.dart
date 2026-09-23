import 'dart:io';
import 'dart:ui' as ui;

import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/agent_models.dart';
import '../platform/svg_image.dart';

class MiniappIconStore {
  static Future<String> import(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final mimeType = imageBytesMime(bytes);
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw StateError('无法识别图片格式');
    }
    if (mimeType == 'image/svg+xml') {
      throw StateError('小程序图标暂不支持 SVG');
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    final root = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${root.path}/miniapp_icons',
    ).create(recursive: true);
    final extension = extensionFromMime(mimeType);
    final file = File('${directory.path}/${newMessageId()}.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
