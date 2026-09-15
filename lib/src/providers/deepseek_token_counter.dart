import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'deepseek_bpe.dart';

/// A persistent worker keeps tokenization and the vocabulary off the UI isolate.
class DeepSeekTokenCounter {
  static Future<SendPort>? _worker;
  static Future<SendPort> _start() async {
    final asset = await rootBundle.load(
      'assets/tokenizers/deepseek_v4.json.gz',
    );
    final ready = ReceivePort();
    await Isolate.spawn(_serve, (
      ready.sendPort,
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    ));
    final result = await ready.first;
    ready.close();
    if (result is String) throw StateError(result);
    return result as SendPort;
  }

  static Future<int> count(Object? value) async {
    final worker = await (_worker ??= _start());
    final reply = ReceivePort();
    worker.send((reply.sendPort, value));
    final result = await reply.first;
    reply.close();
    if (result is String) throw StateError(result);
    return result as int;
  }
}

void _serve((SendPort, List<int>) init) {
  late final DeepSeekBpe tokenizer;
  try {
    tokenizer = DeepSeekBpe(
      jsonDecode(utf8.decode(gzip.decode(init.$2))) as Map<String, dynamic>,
    );
  } on Object catch (error) {
    init.$1.send(error.toString());
    return;
  }
  int count(Object? value) {
    if (value is String) return tokenizer.count(value);
    if (value is List) return value.fold(0, (n, item) => n + count(item));
    if (value is Map) {
      // Media is not text BPE. Reserve separately instead of tokenizing base64.
      if (value['type'] == 'input_image') return 4096;
      return value.entries.fold(
        8,
        (n, entry) => n + count(entry.key) + count(entry.value),
      );
    }
    return 1;
  }

  final input = ReceivePort();
  init.$1.send(input.sendPort);
  input.listen((message) {
    final (reply, value) = message as (SendPort, Object?);
    try {
      reply.send(count(value));
    } on Object catch (error) {
      reply.send(error.toString());
    }
  });
}
