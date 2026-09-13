import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/message_image.dart';

class ImageInputException implements Exception {
  const ImageInputException(this.message);
  final String message;
}

class MessageImageStore {
  static const maxImages = 4;
  final _picker = ImagePicker();
  late final String directory;

  Future<void> initialize() async {
    final support = await getApplicationSupportDirectory();
    final folder = await Directory(
      '${support.path}/message_images',
    ).create(recursive: true);
    directory = folder.path;
  }

  Future<List<MessageImage>> pick(ImageSource source, int remaining) async {
    final List<XFile> files;
    if (source == ImageSource.camera) {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      files = photo == null ? [] : [photo];
    } else {
      files = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        limit: remaining,
        requestFullMetadata: false,
      );
    }
    return _store(files, remaining);
  }

  Future<List<MessageImage>> recover(int remaining) async {
    if (!Platform.isAndroid) return [];
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return [];
    if (response.exception != null) throw response.exception!;
    return _store(response.files!, remaining);
  }

  Future<List<MessageImage>> _store(List<XFile> files, int remaining) async {
    if (files.length > remaining) {
      throw const ImageInputException('每条消息最多添加 4 张图片，请重新选择');
    }
    final images = <MessageImage>[];
    try {
      for (final file in files) {
        if (await file.length() > 10 * 1024 * 1024) {
          throw const ImageInputException('图片过大，请选择小于 10 MB 的图片');
        }
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType('', headerBytes: bytes);
        final extension = switch (mimeType) {
          'image/jpeg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => throw const ImageInputException('请选择 JPG、PNG 或 WebP 图片'),
        };
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1);
        codec.dispose();
        final path =
            '$directory/${DateTime.now().microsecondsSinceEpoch}.$extension';
        await File(path).writeAsBytes(bytes, flush: true);
        images.add(
          MessageImage(
            path: path,
            mimeType: mimeType!,
            name: Platform.isAndroid && file.name.startsWith('scaled_')
                ? file.name.substring(7)
                : file.name,
          ),
        );
      }
      return images;
    } on Object {
      await remove(images);
      rethrow;
    }
  }

  Future<MessageImage> importBytes(List<int> bytes) async {
    final file = XFile.fromData(Uint8List.fromList(bytes));
    return (await _store([file], 1)).single;
  }

  Future<void> remove(Iterable<MessageImage> images) async {
    for (final image in images) {
      await File(image.path).delete();
    }
  }
}
