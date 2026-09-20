import 'package:flutter/material.dart';

import '../../domain/message_file.dart';
import 'attachment_action_icon.dart';

class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.file});

  final MessageFile file;

  AttachmentActionIconType get _type {
    if (file.isHtml) return AttachmentActionIconType.html;
    final extension = file.name.split('.').last.toLowerCase();
    final mime = file.mimeType.toLowerCase();
    if (const {
          'xls',
          'xlsx',
          'xlsm',
          'xlsb',
          'csv',
          'ods',
        }.contains(extension) ||
        mime == 'application/vnd.ms-excel' ||
        mime.contains('spreadsheetml') ||
        mime == 'text/csv' ||
        mime == 'application/vnd.oasis.opendocument.spreadsheet') {
      return AttachmentActionIconType.excel;
    }
    if (const {'doc', 'docx', 'docm', 'odt', 'rtf'}.contains(extension) ||
        mime == 'application/msword' ||
        mime.contains('wordprocessingml') ||
        mime == 'application/vnd.oasis.opendocument.text') {
      return AttachmentActionIconType.word;
    }
    if (extension == 'pdf' || mime == 'application/pdf') {
      return AttachmentActionIconType.pdf;
    }
    if (const {
          'ppt',
          'pptx',
          'pptm',
          'pps',
          'ppsx',
          'odp',
        }.contains(extension) ||
        mime == 'application/vnd.ms-powerpoint' ||
        mime.contains('presentationml') ||
        mime == 'application/vnd.oasis.opendocument.presentation') {
      return AttachmentActionIconType.presentation;
    }
    if (const {
          'mp3',
          'wav',
          'flac',
          'm4a',
          'aac',
          'ogg',
          'opus',
          'wma',
          'aiff',
        }.contains(extension) ||
        mime.startsWith('audio/')) {
      return AttachmentActionIconType.audio;
    }
    if (const {
          'mp4',
          'mov',
          'mkv',
          'avi',
          'webm',
          'm4v',
          '3gp',
          'mpeg',
          'mpg',
        }.contains(extension) ||
        mime.startsWith('video/')) {
      return AttachmentActionIconType.video;
    }
    if (const {
          'apk',
          'apks',
          'xapk',
          'aab',
          'ipa',
          'exe',
          'msi',
          'dmg',
          'pkg',
          'deb',
          'rpm',
        }.contains(extension) ||
        mime == 'application/vnd.android.package-archive') {
      return AttachmentActionIconType.package;
    }
    if (const {'epub', 'mobi', 'azw', 'azw3', 'fb2'}.contains(extension) ||
        const {
          'application/epub+zip',
          'application/x-mobipocket-ebook',
        }.contains(mime)) {
      return AttachmentActionIconType.ebook;
    }
    if (const {
          'js',
          'jsx',
          'ts',
          'tsx',
          'py',
          'dart',
          'json',
          'jsonl',
          'java',
          'kt',
          'kts',
          'swift',
          'c',
          'h',
          'cpp',
          'hpp',
          'cs',
          'go',
          'rs',
          'rb',
          'php',
          'css',
          'scss',
          'xml',
          'yaml',
          'yml',
          'toml',
          'sql',
          'sh',
          'bash',
          'zsh',
          'vue',
          'svelte',
        }.contains(extension) ||
        const {
          'application/json',
          'application/ld+json',
          'application/javascript',
          'text/javascript',
          'application/xml',
          'text/xml',
          'application/yaml',
          'text/yaml',
          'text/css',
          'text/x-python',
          'application/x-sh',
        }.contains(mime)) {
      return AttachmentActionIconType.code;
    }
    if (const {'txt', 'md', 'markdown', 'log', 'rst'}.contains(extension) ||
        mime.startsWith('text/')) {
      return AttachmentActionIconType.text;
    }
    if (const {
          'zip',
          'rar',
          '7z',
          'tar',
          'gz',
          'bz2',
          'xz',
        }.contains(extension) ||
        const {
          'application/zip',
          'application/x-7z-compressed',
          'application/vnd.rar',
          'application/x-rar-compressed',
          'application/gzip',
          'application/x-tar',
        }.contains(mime)) {
      return AttachmentActionIconType.archive;
    }
    return AttachmentActionIconType.file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final type = _type;
    final color = switch (type) {
      AttachmentActionIconType.word =>
        dark ? const Color(0xFF86B5FF) : const Color(0xFF356AC3),
      AttachmentActionIconType.excel =>
        dark ? const Color(0xFF76CCA4) : const Color(0xFF27815A),
      AttachmentActionIconType.pdf =>
        dark ? const Color(0xFFFF9696) : const Color(0xFFC44C4C),
      AttachmentActionIconType.presentation =>
        dark ? const Color(0xFFFFB07C) : const Color(0xFFB9672F),
      AttachmentActionIconType.archive =>
        dark ? const Color(0xFFBDA1EE) : const Color(0xFF835AB5),
      AttachmentActionIconType.audio =>
        dark ? const Color(0xFFE9A0CD) : const Color(0xFFA94A87),
      AttachmentActionIconType.video =>
        dark ? const Color(0xFFBDA1EE) : const Color(0xFF835AB5),
      AttachmentActionIconType.code =>
        dark ? const Color(0xFF78C9D6) : const Color(0xFF267A89),
      AttachmentActionIconType.package =>
        dark ? const Color(0xFF76CCA4) : const Color(0xFF27815A),
      AttachmentActionIconType.ebook =>
        dark ? const Color(0xFFE0BB7D) : const Color(0xFF946B27),
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return AttachmentActionIcon(type: type, color: color);
  }
}
