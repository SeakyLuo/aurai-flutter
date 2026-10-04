import 'miniapp_card_capability.dart';
import 'miniapp_member_capability.dart';
import 'miniapp_reply_capability.dart';
import 'miniapp_message_capability.dart';

/// Capabilities are injected by the host, never supplied by program source.
/// Every handler uses the event transaction and propagates failures to it.
class MiniappProgramCapabilities {
  const MiniappProgramCapabilities({
    this.cards = const MiniappCardCapability(),
    this.members = const MiniappMemberCapability(),
    this.replies = const MiniappReplyCapability(),
    this.messages = const MiniappMessageCapability(),
  });

  final MiniappCardCapability cards;
  final MiniappMemberCapability members;
  final MiniappReplyCapability replies;
  final MiniappMessageCapability messages;
}
