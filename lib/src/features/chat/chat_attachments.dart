part of 'chat_page.dart';

extension _ChatAttachments on _ChatPageState {
  bool _imageOperationPending() {
    if (!widget.controller.addingImages) return false;
    _imageNotice('正在处理附件，请稍候');
    return true;
  }

  Future<void> _addImages(BuildContext buttonContext) async {
    final controller = widget.controller;
    if (controller.addingImages || controller.isBusy || _preparingGoal) return;
    final source = await showImageSourceMenu(buttonContext);
    if (source == null || !mounted) return;
    if (source == AttachmentSource.file) {
      if (controller.draftFiles.length == MessageFileStore.maxFiles) {
        _imageNotice('每条消息最多添加 10 个文件');
        return;
      }
      try {
        await controller.addFiles();
      } on Object catch (error) {
        if (mounted)
          _imageNotice(
            error is PlatformException
                ? error.message ?? '附件添加失败'
                : '附件添加失败，请重试',
          );
      }
    } else {
      if (controller.draftImages.length == MessageImageStore.maxImages) {
        _imageNotice('每条消息最多添加 4 张图片，请先移除一张');
        return;
      }
      await _loadImages(
        source == AttachmentSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
    }
  }

  Future<void> _loadImages([ImageSource? source]) async {
    try {
      await widget.controller.addImages(source);
    } on Object catch (error) {
      if (!mounted) return;
      final permissionDenied =
          error is PlatformException &&
          {
            'camera_access_denied',
            'camera_access_denied_without_prompt',
            'camera_access_restricted',
            'photo_access_denied',
            'photo_access_denied_without_prompt',
            'photo_access_restricted',
          }.contains(error.code);
      _imageNotice(
        permissionDenied
            ? '请在系统设置中允许相机或照片访问'
            : switch (error) {
                ImageInputException() => error.message,
                PlatformException(code: 'no_available_camera') => '当前设备没有可用的相机',
                _ => '图片添加失败，请重新选择',
              },
        action: permissionDenied
            ? SnackBarAction(
                label: '去设置',
                onPressed: () async {
                  try {
                    await widget.controller.openAppSettings();
                  } on Object {
                    if (mounted) _imageNotice('无法打开设置，请在系统设置中找到 Aurai');
                  }
                },
              )
            : null,
      );
    }
  }

  Future<void> _removeImage(MessageImage image) async {
    try {
      await widget.controller.removeDraftImage(image);
    } on Object {
      if (mounted) _imageNotice('图片移除后保存失败，请重试');
    }
  }

  void _imageNotice(String message, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), action: action));
}
