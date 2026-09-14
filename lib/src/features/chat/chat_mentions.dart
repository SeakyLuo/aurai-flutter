part of 'chat_page.dart';

extension _ChatMentions on _ChatPageState {
  void _trackMentions() {
    final value = _textController.value;
    final current = value.text;
    final old = _mentionText;
    _mentionText = current;
    final conversationId = widget.controller.activeConversation.id;
    if (_mentionConversationId != conversationId) {
      _mentionConversationId = conversationId;
      return;
    }
    if (current == old) return;
    var prefix = 0;
    while (prefix < old.length &&
        prefix < current.length &&
        old[prefix] == current[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < old.length - prefix &&
        suffix < current.length - prefix &&
        old[old.length - suffix - 1] == current[current.length - suffix - 1]) {
      suffix++;
    }
    final oldEnd = old.length - suffix;
    final delta = current.length - old.length;
    _mentions.removeWhere((mention) {
      final end = mention.start + mention.text.length;
      if ((prefix < end && oldEnd > mention.start) ||
          (prefix == oldEnd && prefix > mention.start && prefix < end))
        return true;
      if (oldEnd <= mention.start) mention.start += delta;
      return false;
    });
    if (_mentionOpen ||
        widget.controller.activeConversation.kind != ConversationKind.group ||
        !value.selection.isCollapsed ||
        !value.composing.isCollapsed)
      return;
    final cursor = value.selection.extentOffset;
    if (cursor > 0 &&
        current.substring(prefix, current.length - suffix) == '@' &&
        current[cursor - 1] == '@') {
      _pickMention(cursor - 1, current, conversationId);
    }
  }

  Future<void> _pickMention(
    int start,
    String original,
    String conversationId,
  ) async {
    _mentionOpen = true;
    final selection = _textController.selection;
    _focusNode.unfocus();
    final result = await showGroupMentionSheet(
      context,
      widget.controller.groupStore,
      conversationId,
    );
    if (!mounted) return;
    if (widget.controller.activeConversation.id == conversationId &&
        _textController.text == original) {
      if (result != null) {
        final label = result.isEmpty ? '@所有人' : '@${result.single.name}';
        final text = original.replaceRange(start, start + 1, '$label ');
        _textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: start + label.length + 1),
        );
        _mentions.add(
          DraftMention(start, label, result.isEmpty ? null : result.single.id),
        );
        _textController.refreshMentions();
      } else {
        _textController.selection = selection;
      }
      _focusNode.requestFocus();
    }
    _mentionOpen = false;
  }

  void _mentionMember(MessageSender sender) {
    final value = _textController.value;
    final start = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid ? value.selection.end : start;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(value.text[start - 1])
        ? ' '
        : '';
    final label = '@${sender.name}';
    final inserted = '$prefix$label ';
    _textController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _mentions.add(DraftMention(start + prefix.length, label, sender.id));
    _textController.refreshMentions();
    _focusNode.requestFocus();
  }

  List<String>? get _mentionedRecipients =>
      _mentions.isEmpty || _mentions.any((m) => m.senderId == null)
      ? null
      : _mentions.map((m) => m.senderId!).toSet().toList();
}
