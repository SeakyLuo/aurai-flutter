import 'package:flutter/material.dart';
import 'pinned_message_split.dart';

Future<void> openProfileRoute(
  BuildContext context,
  MaterialPageRoute<void> route,
) async {
  final split = context.findAncestorStateOfType<PinnedMessageSplitState>();
  if (split != null && split.supportsSplit) {
    await split.openProfile(route);
  } else {
    await Navigator.of(context).push<void>(route);
  }
}
