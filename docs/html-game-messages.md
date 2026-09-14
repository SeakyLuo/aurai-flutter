# HTML 小游戏消息

当前关闭：`HtmlGameFeature.enabled = false`。三个工具不会注册给模型，事件队列也不会唤醒 AI。已有原生互动卡片不受影响。

开启后仅用于群聊。`createHtmlGame` 创建消息，`readHtmlGame` 读取最新状态，`actHtmlGame` 提交 AI 的单次动作。创建者和用户必须在参与名单中，最多 8 人。

## 展示和生命周期

消息可见时自动内嵌 Android WebView，直接操作；全局最多运行一个。当前可见卡保留所有权，其他卡点击切换；离屏、离开页面或进入后台释放。展开只调整消息内高度，不跳页。其他平台暂不支持运行。

AI 在创建时指定 `width`（180–600，null 表示自适应）和 `height`（180–640），单位为 Flutter 逻辑像素，height 作为内容高度上限。独立 DOM 根节点通过 ResizeObserver 测量实际高度，避免空白；HTML 必须响应式布局，不能用全屏最小高度撑开消息。未加载时使用紧凑占位。

HTML/CSS/JS 自包含，可使用 Canvas、内嵌 data 图片。宿主提供主题 CSS 变量与低优先级表单样式。普通表单值在 SharedPreferences 中按消息保存，恢复后发出 aurai:restore 事件；只应重新计算本地结果，不重放提交动作。禁止网络、外部资源、iframe、文件访问和手机权限。HTML 最大 256 KiB，状态最大 64 KiB。

## 网页通信

```javascript
const unsubscribe = AuraiGame.subscribe(snapshot => render(snapshot));
// 首次订阅立即提供状态，此后接收用户或 AI 的更新。
const current = AuraiGame.snapshot;
const result = await AuraiGame.commit({
  eventId: crypto.randomUUID(),
  expectedVersion: current.version,
  state: nextState,                 // 完整 JSON 对象
  action: '落子',                   // 简短事件描述
  turnSenderId: nextPlayer,         // null 表示任意参与者可行动
  status: 'active',                 // 或 finished
  notifySenderIds: [nextPlayer]     // 只通知需要行动的 AI，不包含用户或自己
});
if (!result.applied) {
  // 根据返回的最新 state/version 重新决策，不能盲目重发旧状态。
}
```

订阅快照还包含参与者、当前轮次和消息信息。动画在网页本地执行，只在关键操作提交状态，不逐帧调用模型。参与者 ID 从上下文获取，不在界面显示或要求用户填写。

每项成功动作在 SQLite 事务中写入状态、版本和通知记录后才返回成功。相同操作重试复用 eventId；不同操作使用新编号。超时后需重新打开并读取状态，不能假定提交失败。宿主校验成员身份、轮次、版本和幂等；具体游戏规则仍由游戏及参与 AI 实现。

AI 无须等网页打开即可通过工具读取、修改状态。通知加入持久队列，AI 空闲时处理；成功完成才确认。连续失败三次后暂停自动重试，卡片提供“重试 AI 回合”，不会重复执行玩家动作。若创建时轮到另一位 AI，会自动排队首次通知。

## 存储

SQLite 升至版本 20，新增 `html_games`、`html_game_events`、`html_game_receipts` 三张表，分别保存内容/尺寸/状态/预览、动作记录和 AI 处理回执。消息使用 `html_game` 类型。列表批量加载卡片元数据，不逐条查库；完整 HTML 只在打开时加载。预览绑定状态版本，状态更新即失效。
