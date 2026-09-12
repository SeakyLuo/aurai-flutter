# 项目约定

## 图标风格

- 新增或调整图标时，必须与项目现有图标风格一致：简洁、圆润的线稿，统一线宽、圆角端点、圆角连接和视觉尺寸。
- 优先复用或扩展现有图标组件，不要直接使用风格不一致的 Material 默认图标，也不要另起一套图标风格。
- 设置页图标以 `lib/src/features/chat/settings_icon.dart` 中的 `SettingsIcon` 为准；其他入口可参考 `lib/src/features/chat/sidebar_action_icon.dart` 中的 `SidebarActionIcon`。
- 当前线稿规范：24 × 24 画布、1.65 线宽、`PaintingStyle.stroke`、`StrokeCap.round`、`StrokeJoin.round`；默认颜色使用主题的 `colorScheme.onSurfaceVariant`，适配亮色与暗色模式。
- 顶部圆形操作按钮的液态玻璃效果复用汉堡菜单使用的 `GlassSurface` 与 `RoundAction`，设置页优先使用 `SettingsGlassAction`。
