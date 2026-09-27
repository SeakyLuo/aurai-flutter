import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import '../domain/agent_models.dart';
import '../domain/message_file.dart';

class GeneratedFileStore {
  GeneratedFileStore(this.attachmentDirectory, this.conversationId);

  final String attachmentDirectory;
  final String conversationId;

  Future<MessageFile> snapshot(String sourcePath, String name) async {
    if (name.isEmpty ||
        name.length > 120 ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(name)) {
      throw ArgumentError('文件名需为 1–120 字，不能包含路径或控制字符');
    }
    final workspace = Directory(
      '${Directory(attachmentDirectory).parent.path}/agent-workspaces/'
      '${base64Url.encode(utf8.encode(conversationId))}',
    );
    final root = await workspace.resolveSymbolicLinks();
    final source = File(sourcePath).isAbsolute
        ? File(sourcePath)
        : File('$root/$sourcePath');
    final path = await source.resolveSymbolicLinks();
    if (!path.startsWith('$root${Platform.pathSeparator}')) {
      throw ArgumentError('只能发送当前会话工作目录内的文件');
    }
    final input = File(path);
    final size = await input.length();
    if (size > 100 * 1024 * 1024) throw ArgumentError('文件不能超过 100 MB');
    final suffix = name.contains('.') ? '.${name.split('.').last}' : '';
    final output = File('$attachmentDirectory/${newMessageId()}$suffix');
    var copied = false;
    try {
      final destination = await output.open(mode: FileMode.write);
      var actualSize = 0;
      final header = <int>[];
      try {
        await for (final chunk in input.openRead()) {
          actualSize += chunk.length;
          if (actualSize > 100 * 1024 * 1024)
            throw ArgumentError('文件不能超过 100 MB');
          if (header.length < 256)
            header.addAll(chunk.take(256 - header.length));
          await destination.writeFrom(chunk);
        }
        await destination.flush();
      } finally {
        await destination.close();
      }
      final result = MessageFile(
        path: output.path,
        name: name,
        mimeType:
            lookupMimeType(name) ??
            lookupMimeType(name, headerBytes: header) ??
            'application/octet-stream',
        size: actualSize,
      );
      copied = true;
      return result;
    } finally {
      if (!copied && await output.exists()) await output.delete();
    }
  }
}
