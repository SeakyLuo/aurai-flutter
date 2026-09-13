import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';

class PreviewImageActions {
  static const _channel = MethodChannel('com.haiskynology.aurai/platform');

  static Future<Uint8List> readBytes(ImageProvider provider) async {
    if (provider is ResizeImage) return readBytes(provider.imageProvider);
    if (provider is FileImage) return provider.file.readAsBytes();
    if (provider is MemoryImage) return provider.bytes;
    if (provider is NetworkImage) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final request = await client.getUrl(Uri.parse(provider.url));
        provider.headers?.forEach(request.headers.set);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok)
          throw const HttpException('图片下载失败');
        return await consolidateHttpClientResponseBytes(
          response,
        ).timeout(const Duration(seconds: 60));
      } finally {
        client.close(force: true);
      }
    }
    throw StateError('此图片暂不支持导出');
  }

  static Future<bool> perform(ImageProvider image, String action) async {
    final bytes = await readBytes(image);
    final mime = lookupMimeType('', headerBytes: bytes);
    if (mime == null || !mime.startsWith('image/'))
      throw StateError('无法识别图片格式');
    return await _channel.invokeMethod<bool>('previewImageAction', {
          'bytes': bytes,
          'mimeType': mime,
          'action': action,
          'name':
              'Aurai_${DateTime.now().millisecondsSinceEpoch}.${extensionFromMime(mime)}',
        }) ??
        false;
  }
}
