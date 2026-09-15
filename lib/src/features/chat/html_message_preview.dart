import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'message_preview_text.dart';
import 'settings_appearance.dart';

/// A passive snapshot: previews never create or run a WebView.
class HtmlMessagePreview extends StatelessWidget {
  const HtmlMessagePreview({
    super.key,
    required this.title,
    this.preview,
    this.query = '',
    this.fitAvailableHeight = false,
  });
  final bool fitAvailableHeight;
  final String title, query;
  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: MessagePreviewText(
              text: title,
              literal: true,
              query: query,
              maxLines: 2,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (preview != null)
            if (fitAvailableHeight)
              Flexible(child: _image(context))
            else
              SizedBox(height: 160, child: _image(context)),
        ],
      ),
    );
  }

  Widget _image(BuildContext context) => Image.memory(
    preview!,
    width: double.infinity,
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,
    cacheWidth: (320 * MediaQuery.devicePixelRatioOf(context)).round(),
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
