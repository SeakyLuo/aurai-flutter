# HTML 小程序直接调用 AI

Android HTML 小程序可以通过 `AuraiHTML.ai` 使用 Aurai 的默认文本模型。接口与具体应用无关，TipOff 和后续小程序使用同一个入口。

每次请求从宿主读取最新 `ModelSettings.activeConfig`，复用默认文本模型、供应商账号、接口协议及推理配置。密钥和供应商原始错误留在原生侧；页面不能指定密钥、地址或切换账号。请求不携带 Aurai 聊天历史、用户记忆或 Agent 工具。

## 用法

```javascript
const status = await AuraiHTML.ai.getStatus();
// {version:1, available:true, model:'...'}
// 或 {version:1, available:false, reason:'请先在 Aurai 设置默认文本模型'}

const controller = new AbortController();
const result = await AuraiHTML.ai.complete({
  messages: [
    {role: 'system', content: '根据用户给出的比赛事实撰写短新闻。'},
    {role: 'user', content: '球队以 101:98 获胜，球员得到 25 分。'}
  ],
  responseFormat: 'text',
  maxOutputTokens: 4096
}, {
  signal: controller.signal,
  onText: text => renderDraft(text) // 累计全文，不是增量 token；可省略
});
// {text, model}
// controller.abort() 可取消尚未完成的请求。
```

`messages` 支持 system/user/assistant 纯文本消息。`responseFormat: 'json'` 会要求模型返回 JSON，并由宿主解析，成功时返回 `{text, json, model}`。这不是 JSON Schema 强约束；无效 JSON 会拒绝 Promise，业务仍需验证字段与合法性。不要将流式草稿当作最终结果保存。

API 版本为 `AuraiHTML.ai.version === 1`。旧宿主没有该属性时应提示更新，不应悄悄切到其他账号或改成聊天任务。

## 生命周期与限制

- 每个页面最多 4 个进行中的推理请求，1–100 条消息，请求 JSON 最大 256 KiB。
- 输出 token 默认 4096，可请求 1–32768，最终不超过现有模型配置的输出上限。文本最多 512 KiB。
- 原生总超时 120 秒；JavaScript 桥接有 130 秒兜住失去响应的情况，两者都会取消原生请求。
- 页面隐藏、关闭、被替换或手动 abort 时取消请求。不跨页面持久运行；重新打开不自动重发。
- 使用现有 ResponsesTransport 的网络重连策略，但接口不自动重做业务操作。
- 错误通过 rejected Error 传回，可读取 `error.code`；页面用 toast 展示可理解的消息。
- `getStatus()` 只说明配置是否齐全，不代表已经连接供应商或拥有可用额度。

## 与 submitEvent 的区别

`ai.complete` 返回推理结果，由小程序校验后显式保存。它不执行工具、不写应用文件、不向会话发送消息，也不自动通知会话 AI。

`submitEvent` 仍保留原有语义：排队唤醒会话里的 Agent，Promise 只确认排队，不代表任务完成。需要 Agent 工具或持续后台任务时才使用它，不能把两种完成时机混为一谈。

此接口用于 Aurai 内托管的 HTML 页面，不是向局域网暴露的 HTTP 服务。独立浏览器网页不会自动获得手机上的模型配置。

## 实现位置与验证

- `html_ai_service.dart`：默认模型、请求验证、超时/取消、返回值隔离。
- `html_ai_script.dart`：Promise、流式回调、AbortSignal。
- `html_game_session.dart` 与 Android `HtmlGameView.kt`：页面生命周期和原生桥接。
- `html_app_data_tool.dart`：生成小程序时提供给 Agent 的通用接口说明。

完成 Dart 静态分析和 Android Kotlin 编译；未安装 App，也未在手机上完成真实供应商往返验证。

## AI 管理发布

聊天 AI 已注册 `listHtmlAppPublications`、`readHtmlAppPublication`、`publishHtmlApp`、`updateHtmlAppPublication`、`withdrawHtmlApp`。先按名称查找并读取版本，再按用户要求发布或撤下；修改操作必须提供 `expectedRevision`，不会自动重试过时版本。AI 只能管理自己创建或用户拥有的作品，不能将添加的副本重新署名发布。发布署名使用用户资料，内置小程序随 App 更新。
