import 'dart:io';

class MessageImage {
  const MessageImage({required this.path, required this.mimeType, this.name});

  final String path;
  final String mimeType;
  final String? name;

  Map<String, Object?> toJson() => {
    'fileName': File(path).uri.pathSegments.last,
    'mimeType': mimeType,
    'name': name,
  };

  factory MessageImage.fromJson(Map<String, Object?> json, String directory) =>
      MessageImage(
        path: '$directory/${json['fileName']! as String}',
        mimeType: json['mimeType']! as String,
        name: json['name'] as String?,
      );
}
