import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../../domain/agent_models.dart';

class ProviderIconStore {
  static Future<String> import(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
    late final List<int> png;
    try {
      final frame = await codec.getNextFrame();
      try {
        png = (await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    final root = await getApplicationSupportDirectory();
    final folder = await Directory(
      '${root.path}/provider_icons',
    ).create(recursive: true);
    final file = File('${folder.path}/${newMessageId()}.png');
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }
}
