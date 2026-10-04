import 'package:flutter/material.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'contact_profile_split.dart';
import 'pinned_message_split.dart';
import 'project_profile_page.dart';

Future<bool?> openProjectProfile(
  BuildContext context,
  ChatController controller,
  DevelopmentProject project,
) {
  Widget page(BuildContext _) =>
      ProjectProfilePage(controller: controller, project: project);
  final chatSplit = context.findAncestorStateOfType<PinnedMessageSplitState>();
  if (chatSplit != null && chatSplit.supportsSplit) {
    return chatSplit.openDetails(page);
  }
  final split = context.findAncestorStateOfType<ContactProfileSplitState>();
  final route = MaterialPageRoute<bool>(builder: page);
  if (split != null && split.supportsSplit) return split.open(route);
  return Navigator.of(context).push(route);
}
