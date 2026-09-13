part of 'chat_page.dart';

extension _ChatGroupNavigation on _ChatPageState {
  Future<void> _openGroups({required bool create}) async {
    if (_imageOperationPending()) return;
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => create
            ? GroupCreatePage(controller: widget.controller)
            : GroupChatPage(controller: widget.controller),
      ),
    );
    if (mounted && id != null) {
      _scaffoldKey.currentState!.closeDrawer();
      await _changeConversation(id);
    }
  }
}
