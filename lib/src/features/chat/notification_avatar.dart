import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import 'group_avatar.dart';
import 'member_avatar.dart';

class NotificationAvatar {
  NotificationAvatar(this.store);
  final GroupChatStore store;

  Future<Uint8List> render(String conversationId) async {
    final rows = await store.database.query(
      'conversations',
      columns: ['kind', 'default_sender_id'],
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    final group = rows.single['kind'] == 'group';
    final List<MessageSender> senders;
    if (group) {
      senders = (await store.avatarMembers([conversationId]))[conversationId]!;
    } else {
      senders = [
        (await store.loadAi(rows.single['default_sender_id'] as String)).sender,
      ];
    }
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
          child: group
              ? GroupAvatar(members: senders, size: size)
              : MemberAvatar(sender: senders.single, size: size),
        ),
      ),
    );
    final root = adapter.attachToRenderTree(owner);
    try {
      await Future.wait([
        for (final sender in senders)
          if (sender.avatarPath != null)
            precacheImage(
              FileImage(File(sender.avatarPath!)),
              root,
              onError: (_, _) {},
            )
          else if (sender.avatarIcon == 'app_logo' ||
              sender.avatarIcon == 'app_logo_white')
            precacheImage(
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
      final image = await boundary.toImage(pixelRatio: 3);
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
}
