import 'dart:io';

class MessageFile {
  const MessageFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
  });
  final String path;
  final String name;
  final String mimeType;
  final int size;
  String get id => File(path).uri.pathSegments.last;
  Map<String, Object?> toJson() => {
    'fileName': id,
    'name': name,
    'mimeType': mimeType,
    'size': size,
  };
  factory MessageFile.fromJson(Map<String, Object?> json, String directory) =>
      MessageFile(
        path: '$directory/${json['fileName']}',
        name: json['name'] as String,
        mimeType: json['mimeType'] as String,
        size: json['size'] as int,
      );
}
