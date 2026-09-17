# 项目约定
- 不要安装App到手机

## 图标风格

- 新增或调整图标时，必须与项目现有图标风格一致：简洁、圆润的线稿，统一线宽、圆角端点、圆角连接和视觉尺寸。
- 优先复用或扩展现有图标组件，不要直接使用风格不一致的 Material 默认图标，也不要另起一套图标风格。
- 设置页图标以 `lib/src/features/chat/settings_icon.dart` 中的 `SettingsIcon` 为准；其他入口可参考 `lib/src/features/chat/sidebar_action_icon.dart` 中的 `SidebarActionIcon`。
- 当前线稿规范：24 × 24 画布、1.65 线宽、`PaintingStyle.stroke`、`StrokeCap.round`、`StrokeJoin.round`；默认颜色使用主题的 `colorScheme.onSurfaceVariant`，适配亮色与暗色模式。
- 顶部圆形操作按钮的液态玻璃效果复用汉堡菜单使用的 `GlassSurface` 与 `RoundAction`，设置页优先使用 `SettingsGlassAction`。

## 弹框按钮

- 新增或修改弹框前，先检查现有项目弹框组件；业务代码禁止使用 `AlertDialog`、`SimpleDialog`、`CupertinoAlertDialog` 或自行拼装系统默认弹框。
- 普通确认/取消提示使用 `lib/src/features/chat/app_confirmation_dialog.dart` 的 `AppConfirmationDialog`，只提供文案和确认操作角色；确认返回 `true`，取消返回 `false`，关闭返回 `null`。删除或放弃修改复用 `DeleteConfirmationDialog`，归档会话复用 `ArchiveConfirmationDialog`。
- 多操作提示使用 `lib/src/features/chat/app_dialog.dart` 的 `AppPromptDialog`；自定义表单、选择器使用同文件的 `AppDialog`，内容自行处理滚动。统一复用玻璃背景、圆角、宽度和边距，不得在业务页面新增裸 `Dialog` 或复制一套弹框外壳。
- 保存/放弃/继续编辑三选一复用 `TaskUnsavedDialog`，保留既有返回值语义。`showDialog` 仅负责打开弹框，不代表允许使用系统默认样式。

- 确认弹框统一使用 `lib/src/features/chat/dialog_action_button.dart` 的 `DialogActionButton`，调用处只提供 `text`、`onPressed`、`role` 和可选 `detail`；不要重复设置颜色、圆角、高度或自行拼装按钮。
- `primary` 为确认操作，`secondary` 为取消或拒绝，`destructive` 为删除等破坏性操作。主按钮内部复用 `WidgetUtils.primaryButton`，保持全局渐变和胶囊形状一致。
