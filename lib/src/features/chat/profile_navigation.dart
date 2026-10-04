import 'package:flutter/material.dart';
import 'pinned_message_split.dart';
import 'contact_profile_split.dart';

Future<void> openProfileRoute(
  BuildContext context,
  MaterialPageRoute<void> route,
) async {
  final split = context.findAncestorStateOfType<PinnedMessageSplitState>();
  if (split != null && split.supportsSplit) {
    await split.openProfile(route);
    return;
  }
  final profileSplit = context
      .findAncestorStateOfType<ContactProfileSplitState>();
  if (profileSplit != null && profileSplit.supportsSplit) {
    await profileSplit.open(route);
    return;
  }
  await Navigator.of(context).push<void>(route);
}
