import 'dart:io';
import 'package:flutter/services.dart';
import '../domain/message_file.dart';

class MessageFileStore {
  static const maxFiles = 10;
  static const channel = MethodChannel('com.haiskynology.aurai/platform');
  static Future<List<MessageFile>> pick(String directory, int remaining) async {
    final values = await channel.invokeListMethod<dynamic>('pickChatFiles', {
      'directory': directory,
      'remaining': remaining,
    });
    return values!.map((value) {
      final row = value as Map;
      return MessageFile(
        path: row['path'] as String,
        name: row['name'] as String,
        mimeType: row['mimeType'] as String,
        size: row['size'] as int,
      );
    }).toList();
  }

  static Future<void> remove(Iterable<MessageFile> files) async {
    for (final file in files) {
      await File(file.path).delete();
    }
  }

  static Future<void> open(MessageFile file) => channel.invokeMethod(
    'openChatFile',
    {'path': file.path, 'name': file.name, 'mimeType': file.mimeType},
  );
}
