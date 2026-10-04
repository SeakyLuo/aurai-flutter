part of 'chat_page.dart';

extension _ChatComposer on _ChatPageState {
  Future<void> _chooseDraftVisibility() async {
    final id = _conversationId;
    await runUiAction(context, () async {
      final members = await widget.controller.groupStore.members(id);
      if (!mounted || _conversationId != id) return;
      _focusNode.unfocus();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => SendOptionsSheet(
          initial: _draftVisibility[id],
          members: members.map((m) => m.sender).toList(),
          mentionedMemberIds: {
            if (_mentions.any((mention) => mention.senderId == null))
              ...members.map((member) => member.sender.id)
            else
              ..._mentions.map((mention) => mention.senderId!),
          },
          onChanged: (result) {
            if (!mounted || _conversationId != id) return;
            _updateDraftVisibility(() {
              if (result.mode == DraftVisibilityMode.everyone) {
                _draftVisibility.remove(id);
              } else {
                _draftVisibility[id] = result;
              }
            });
          },
        ),
      );
    });
  }

  Widget _buildChatComposer(bool isGroup) {
    final controller = widget.controller;
    return GroupMuteBuilder(
      store: controller.groupStore,
      groupId: isGroup ? _conversationId : null,
      builder: (context, muted, muteHint) => ChatComposer(
        controller: _textController,
        hintText: muted
            ? muteHint
            : _editing != null
            ? '编辑消息'
            : isGroup
            ? _draftVisibility[_conversationId]?.label ?? ''
            : '回复 ${controller.activeAi!.sender.name}',
        quote: _editing != null
            ? _editing!.message.quote
            : controller.activeConversation.draftQuote,
        onCancelQuote: _editing == null ? () => _quoteMessage(null) : null,
        focusNode: _focusNode,
        queueing: !isGroup && controller.shouldQueuePrivateMessage,
        savingEdit: _editing?.saving == true,
        submitting: controller.isSubmitting,
        draftEnabled: muted
            ? false
            : _editing != null
            ? !_editing!.saving
            : controller.canEditDraft &&
                  !_preparingGoal &&
                  !controller.creatingConversationBranch,
        enabled: controller.creatingConversationBranch
            ? false
            : isGroup
            ? true
            : _editing != null
            ? !_editing!.saving
            : !controller.isBusy ||
                  _canSend ||
                  controller.draftImages.isNotEmpty ||
                  controller.draftFiles.isNotEmpty,
        canSend:
            !muted &&
            !controller.pendingMessageQueue.busy &&
            (_canSend ||
                (_editing?.images ?? controller.draftImages).isNotEmpty ||
                (_editing?.files ?? controller.draftFiles).isNotEmpty),
        images: _editing?.images ?? controller.draftImages,
        files: _editing?.files ?? controller.draftFiles,
        onRemoveFile: (file) async {
          if (_editing != null) {
            _updateEditing(() => _editing!.files.remove(file));
            return;
          }
          try {
            await controller.removeDraftFile(file);
          } on Object catch (error) {
            if (mounted)
              _imageNotice(
                '附件移除失败，请重试：${errorMessage(error)}',
                kind: ToastKind.error,
              );
          }
        },
        addingImages: controller.addingImages || _editing?.picking == true,
        onAddImages: _editing != null ? _addEditImages : _addImages,
        onRemoveImage: _editing != null ? _removeEditImage : _removeImage,
        stopping: controller.runState == ChatRunState.stopping,
        onSend: _editing != null ? _submitMessageEdit : _send,
        onVisibility: isGroup && _editing == null && !muted
            ? _chooseDraftVisibility
            : null,
        canResume:
            !isGroup &&
            !_preparingGoal &&
            !controller.isBusy &&
            _editing == null &&
            controller.pendingMessageQueue.messages.isEmpty &&
            (controller.runState == ChatRunState.cancelled ||
                controller.runState == ChatRunState.idle) &&
            controller.pendingGoal != null,
        onResume: _continuePending,
        onStop: _stop,
      ),
    );
  }
}
