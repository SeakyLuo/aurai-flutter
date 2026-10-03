import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../domain/message_sender.dart';
import '../domain/avatar_portraits.dart';
import '../features/chat/member_avatar.dart';

/// Reuse the IM avatar widget so miniapps display the same photos and symbols.
class MiniappMemberAvatars {
  static final _images = <String, Future<String>>{};
  static Future<List<Map<String, Object?>>> decorate(
    List<Map<String, Object?>> members,
  ) => Future.wait(
    members.map((row) async {
      final sender = MessageSender.fromRow(row);
      final key = jsonEncode([
        sender.name,
        sender.avatarIcon,
        sender.avatarColor,
        sender.avatarPath,
      ]);
      if (!_images.containsKey(key)) {
        if (_images.length == 96) _images.remove(_images.keys.first);
        _images[key] = _render(
          sender,
        ).then((bytes) => 'data:image/png;base64,${base64Encode(bytes)}');
      }
      return {
        'id': sender.id,
        'name': sender.name,
        'kind': row['kind'],
        'avatar': await _images[key]!,
      };
    }),
  );
  static Future<Uint8List> _render(MessageSender sender) async {
    final senders = [sender];
    const size = 64.0;
    final boundary = RenderRepaintBoundary();
    final pipeline = PipelineOwner();
    final focus = FocusManager();
    final owner = BuildOwner(focusManager: focus);
    final view = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      configuration: const ViewConfiguration(
        logicalConstraints: BoxConstraints.tightFor(width: size, height: size),
        physicalConstraints: BoxConstraints.tightFor(width: size, height: size),
        devicePixelRatio: 1,
      ),
      child: boundary,
    );
    pipeline.rootNode = view;
    view.prepareInitialFrame();
    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(
            brightness:
                WidgetsBinding.instance.platformDispatcher.platformBrightness,
          ),
          child: MemberAvatar(sender: sender, size: size),
        ),
      ),
    );
    final root = adapter.attachToRenderTree(owner);
    try {
      await Future.wait([
        for (final sender in senders)
          if (sender.avatarPath != null)
            _precache(FileImage(File(sender.avatarPath!)), root)
          else if (avatarPortraits.containsKey(sender.avatarIcon))
            _precache(
              AssetImage(avatarPortraits[sender.avatarIcon]!.asset),
              root,
            )
          else if (sender.avatarIcon == 'app_logo' ||
              sender.avatarIcon == 'app_logo_white')
            _precache(
              AssetImage(
                sender.avatarIcon == 'app_logo'
                    ? 'assets/branding/app_logo.png'
                    : 'assets/branding/symbol_white.png',
              ),
              root,
            ),
      ]);
      owner.buildScope(root);
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(owner, root);
      owner.buildScope(root);
      owner.finalizeTree();
      pipeline.rootNode = null;
      view.dispose();
      pipeline.dispose();
      focus.dispose();
    }
  }

  static Future<void> _precache(ImageProvider image, BuildContext context) {
    final result = Completer<void>();
    precacheImage(
      image,
      context,
      onError: (error, stack) => result.completeError(error, stack),
    ).then((_) {
      if (!result.isCompleted) result.complete();
    });
    return result.future;
  }
}
