import 'dart:io';

class MessageImage {
  const MessageImage({required this.path, required this.mimeType});

  final String path;
  final String mimeType;

  Map<String, Object?> toJson() => {
    'fileName': File(path).uri.pathSegments.last,
    'mimeType': mimeType,
  };

  factory MessageImage.fromJson(Map<String, Object?> json, String directory) =>
      MessageImage(
        path: '$directory/${json['fileName']! as String}',
        mimeType: json['mimeType']! as String,
      );
}
