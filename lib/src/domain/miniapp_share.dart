import 'dart:io';

import '../html_games/miniapp_entry.dart';

/// A share captures presentation metadata; opening it resolves the application.
class MiniappShare {
  const MiniappShare({
    required this.uri,
    required this.name,
    required this.title,
    this.iconPath,
    this.iconAsset,
    this.imagePath,
    this.note = '',
  });

  factory MiniappShare.fromEntry(MiniappEntry entry) => MiniappShare(
    uri: Uri(
      scheme: 'aurai',
      host: 'miniapp',
      pathSegments: [
        (entry.kind == MiniappKind.installed
                ? MiniappKind.published
                : entry.kind)
            .name,
        entry.publicationId,
      ],
    ).toString(),
    name: entry.title,
    title: entry.shareTitle.isEmpty ? entry.title : entry.shareTitle,
    iconPath: entry.iconPath,
    iconAsset: entry.iconAsset,
    imagePath: entry.shareImagePath,
  );

  final String uri, name, title, note;
  final String? iconPath, iconAsset, imagePath;
  List<String> get mediaPaths => [
    if (iconPath != null) iconPath!,
    if (imagePath != null) imagePath!,
  ];

  MiniappShare withMediaAndNote({
    String? iconPath,
    String? imagePath,
    required String note,
  }) => MiniappShare(
    uri: uri,
    name: name,
    title: title,
    iconAsset: iconAsset,
    iconPath: iconPath,
    imagePath: imagePath,
    note: note,
  );

  Map<String, Object?> toJson() => {
    'uri': uri,
    'name': name,
    'title': title,
    'note': note,
    'iconAsset': iconAsset,
    'iconFile': iconPath == null ? null : File(iconPath!).uri.pathSegments.last,
    'imageFile': imagePath == null
        ? null
        : File(imagePath!).uri.pathSegments.last,
  };

  factory MiniappShare.fromJson(
    Map<String, Object?> json,
    String imageDirectory,
  ) => MiniappShare(
    uri: json['uri'] as String,
    name: json['name'] as String,
    title: json['title'] as String,
    note: json['note'] as String,
    iconAsset: json['iconAsset'] as String?,
    iconPath: json['iconFile'] == null
        ? null
        : '$imageDirectory/${json['iconFile']}',
    imagePath: json['imageFile'] == null
        ? null
        : '$imageDirectory/${json['imageFile']}',
  );
}
