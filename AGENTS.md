# 项目约定
- 不要安装App到手机，不要未经允许就重启
- 真机数据备份脚本位于 `scripts/.codex_backup_app_data.py`。

## 图标风格

- 新增或调整图标时，必须与项目现有图标风格与颜色一致：简洁、圆润的线稿，统一线宽、圆角端点、圆角连接和视觉尺寸。
- 优先复用或扩展现有图标组件，不要直接使用风格不一致的 Material 默认图标，也不要另起一套图标风格。
- 设置页图标以 `lib/src/features/chat/settings_icon.dart` 中的 `SettingsIcon` 为准；其他入口可参考 `lib/src/features/chat/sidebar_action_icon.dart` 中的 `SidebarActionIcon`。
- 当前线稿规范：24 × 24 画布、1.65 线宽、`PaintingStyle.stroke`、`StrokeCap.round`、`StrokeJoin.round`；默认颜色使用主题的 `colorScheme.onSurfaceVariant`，适配亮色与暗色模式。
- 顶部圆形操作按钮的液态玻璃效果复用汉堡菜单使用的 `GlassSurface` 与 `RoundAction`，设置页优先使用 `SettingsGlassAction`。
- 同一 AppBar 右侧同时出现两个或多个相邻操作时，必须放进同一个 `SettingsGlassActionSurface`，内部使用 `RoundAction` 和 `VerticalDivider` 拼接，禁止显示为多个分离的玻璃圆按钮。

## 插画头像规范

- 新增插画头像使用 imagegen，生成前先查看 `assets/avatars/` 中现有头像作为风格参考，例如 `baby_tiger.webp`、`fox.webp`、`magician_pig.webp`；插画头像沿用现有圆润、亲切的 3D 卡通质感，与界面线稿图标分开处理。
- 使用方形画布、真正透明的背景，不绘制圆角底板、背景场景、文字或水印。主体为大头半身像，脸部突出，毛发或材质细腻，光线柔和；保留物种特征，避免照搬已有影视角色。
- 动作、表情和职业服饰须在小尺寸下清晰可辨；脸、耳朵、帽子与关键动作留出边缘余量，兼顾圆形头像裁切，不用繁杂配件抢占主体。
- 先展示生成预览，用户确认后再保存原图和项目资源，不提前替换或接入头像。原始 PNG 保存到 `C:/Users/luoki/Desktop/Docs/Work/Haiskynology/Aurai/avatars/`，压缩后的 WebP 保存到项目 `assets/avatars/`，使用一致的英文下划线文件名。
- WebP 沿用现有头像的 512 × 512 尺寸，保持透明通道；压缩后检查毛发边缘、面部和动作细节，无黑白底或明显压缩瑕疵。未经要求不覆盖已有头像。
- 接入新头像时，同时登记 `lib/src/domain/avatar_portraits.dart` 的图片资源与 `lib/src/features/chat/avatar_symbol.dart` 的 `avatarSymbols` 选择列表；仅添加资源不会让头像出现在头像库中。需要调整圆形裁切时沿用 `avatarPortraitScales`，小程序成员头像复用现有头像渲染入口。

## 弹框按钮

- 新增或修改弹框前，先检查现有项目弹框组件；业务代码禁止使用 `AlertDialog`、`SimpleDialog`、`CupertinoAlertDialog` 或自行拼装系统默认弹框。
- 普通确认/取消提示使用 `lib/src/features/chat/app_confirmation_dialog.dart` 的 `AppConfirmationDialog`，只提供文案和确认操作角色；确认返回 `true`，取消返回 `false`，关闭返回 `null`。删除或放弃修改复用 `DeleteConfirmationDialog`，归档会话复用 `ArchiveConfirmationDialog`。
- 多操作提示使用 `lib/src/features/chat/app_dialog.dart` 的 `AppPromptDialog`；自定义表单、选择器使用同文件的 `AppDialog`，内容自行处理滚动。统一复用玻璃背景、圆角、宽度和边距，不得在业务页面新增裸 `Dialog` 或复制一套弹框外壳。
- 保存/放弃/继续编辑三选一复用 `TaskUnsavedDialog`，保留既有返回值语义。`showDialog` 仅负责打开弹框，不代表允许使用系统默认样式。
- 确认弹框统一使用 `lib/src/features/chat/dialog_action_button.dart` 的 `DialogActionButton`，调用处只提供 `text`、`onPressed`、`role` 和可选 `detail`；不要重复设置颜色、圆角、高度或自行拼装按钮。
- `primary` 为确认操作，`secondary` 为取消或拒绝，`destructive` 为删除等破坏性操作。主按钮内部复用 `WidgetUtils.primaryButton`，保持全局渐变和胶囊形状一致。

## 开发规范
- 所有错误必须透传给上层处理，禁止在业务代码中自行 catch 或 swallow 异常。
- 工具调用的预检查、授权和执行异常必须在统一执行边界返回给 AI，不得因工具异常中断整轮对话。返回原始异常文本，完整保留错误码、底层原因和服务响应详情，禁止替换为通用提示、翻译或截断报错；取消、超时及后续操作建议使用独立字段，不覆盖原始报错。不得仅因失败就要求或自动原样重试。
- 这是个人项目，不要兼容，直接刷数据即可。
- 开发的时候要严格参考项目风格、复用UI组件，不得随意发挥。
