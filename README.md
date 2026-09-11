# Aurai Flutter

Aurai 是一个由自然语言目标驱动的通用手机 Agent。首版面向 Android / vivo OriginOS，同时保留 iOS 壳层。Agent、对话、工具协议、风险模型和模型接口位于 Dart domain，Android 能力以 adapter 接入。

它没有 `diagnoseChatGPT`、`fixVpn`、`troubleshootSsl` 等固定 workflow。模型动态发现当前 capability 和通用工具，通过“观察 → 行动 → 再观察 → 验证 → 必要时重规划”完成任务。

## 当前能力

- `observeDevice`：设备型号、系统时间/时区/自动校时状态、前台 App、窗口和最多 300 个 Accessibility 节点；节点包含文本、描述、类型、view id、bounds 和可操作状态。
- `captureScreen`：Android 11+ 使用 Accessibility 截取当前窗口；仅在当前模型配置声明支持图像输入时向 Agent 暴露。每次读取都按敏感操作确认，JPEG 附件只存在于当前工具结果中，不写入对话或相册；Android 14+ 优先避开 Aurai 自身浮层。
- `tapScreen`：对最近截图的目标窗口使用归一化坐标执行一次点击。调用前展示带标记的局部预览并逐次确认；执行前重新截取目标窗口，核对 App、窗口、屏幕、旋转、边界、页面指纹、时效和点击邻域变化。成功或结果不确定都会废弃旧截图，禁止盲目重放。
- `act`：携带最近一次观察的 observation id 和节点 ref，执行 click、inputText、scrollForward、scrollBackward、back、home。页面变化会拒绝过期动作，动作后要求模型重新观察。
- `findApps` / `launchApp`：在 Android 允许可见的应用范围内按名称查找并启动 App。
- `startIntent` / `openSettings`：通用 Intent，以及 Wi-Fi、网络、VPN、无障碍、Aurai 应用详情等稳定设置入口。
- `shell`：以 Aurai 普通 App UID 执行本机命令，15 秒上限、输出截断、支持停止；它不是 ADB、root 或系统 shell。
- `getNetworkState`：活动网络、Wi-Fi / cellular / VPN、DNS、route、Private DNS、proxy、validated、captive portal、metered。
- `getNetworkEvents`：保存 Aurai 进程启动后的最近 100 次网络可用、丢失、能力和链路变化，用于关联间歇性错误与 VPN/路由切换。
- `dnsLookup`：使用 Android 默认路由或指定 Wi-Fi、蜂窝、VPN 网络的系统解析器查询域名。
- `tlsProbe`：可在指定网络上执行最多 10 次连续 TCP/TLS 探测；DNS 解析也绑定同一网络，避免“指定网络建连、默认网络解析”的混合结果。成功时返回 ALPN、协议、cipher、证书链、issuer、SAN、有效期、hostname match 和 Android system trust；失败时保留已完成的 DNS/TCP 地址、端点、耗时和有限异常链。
- `httpProbe`：执行最多 60 次、间隔最多 30 秒的有界完整 HTTPS 采样，长时间运行仍可由用户停止。它把失败定位到 DNS、TCP、TLS 证书、TLS 握手、超时或 HTTP 响应阶段，并汇总首次/末次失败与最长连续失败。失败结果仍保留已完成的解析地址、DNS/TCP 耗时、本地与连接对端、失败阶段耗时和有限异常链，便于关联 `ClientHello` 后断开等间歇性路径故障。既可使用 Android 默认/指定网络，也可通过已知 SOCKS5 入口发起请求；HTTP 403 等有效响应会记为传输成功。
- `getNotifications`：读取 Aurai 通知监听在线期间的有限内存窗口，可按易读 App 名、回看分钟数和条数筛选。系统通知访问与模型读取分开授权；发送给模型前，手机端会隐藏验证码、登录安全、付款、转账和银行类正文，并明确返回覆盖起点与是否缺失历史。
- `requestAccessibilityAccess`：任务需要跨 App 观察或操作时，解释用途并等待用户去系统设置授权；返回后自动复查并继续。
- `wait`：短暂等待 UI 或网络状态变化，再重新观察。

TLS probe 使用宽松 trust manager 取得服务端证书链，然后单独调用 Android 系统 trust manager 验证，不会替换 Aurai 正常 HTTPS 的证书校验。

## 架构

`Chat UI → Agent Runtime → ModelProvider → Tool Registry → Tool Executor → Android adapters → observation → replan`

- `lib/src/domain`：`AgentMessage`、`AgentStep`、`ToolDefinition`、`ToolCall`、`ToolResult`、capability、风险等级和 `ModelProvider`。
- `lib/src/agent`：最多 20 轮的 Agent loop、系统约束、动态 Tool Registry、确定性 capability 拦截、风险确认和取消；每项工具声明与自身工作量相符的执行时限，重复网络采样不会被统一短超时提前截断。
- `lib/src/providers`：相互隔离的 OpenAI / DeepSeek Responses API adapter；文本与图像工具结果在 provider 层转换，协议差异不会进入 Agent loop。
- `lib/src/platform`：MethodChannel、通用 Android tools 和 network tools。
- `lib/src/features/chat`：聊天、合并执行进度、停止、重试、中断恢复、模型配置、任务内权限与确认 UI。
- `AuraiAccessibilityService.kt`：UI tree、节点动作、任务悬浮胶囊、跨 App 确认卡、一次性授权和页面级低风险导航授权。
- `AuraiNotificationListenerService.kt`：系统通知监听、有限内存观察窗口、易读 App 名过滤和模型读取前的原生敏感内容隐藏。
- `ExecutionAdapter.kt`：普通 App UID 执行器，以及预留但默认不可用的 Shizuku / ADB adapter 边界。
- `AndroidAgentBridge.kt`：capability、应用、Intent、设置、观察和执行适配。
- `AuraiApplication.kt`：持有唯一的缓存 Flutter Agent Engine、MethodChannel、网络探测、持久化与 Android Keystore；Activity 销毁不会终止正在执行的 Agent loop。
- `AgentSessionService.kt`：跨 App 任务的 Android 前台服务，提供静默状态通知和停止入口；完成或失败时保留可点按查看结果的通知。
- `MainActivity.kt`：只负责承载缓存 Engine 与当前页面需要的系统权限请求。

## 安全边界

- `READ_ONLY` 自动执行；`LOW_RISK` 只覆盖启动 App、打开设置、滚动、返回和 Home 等确定动作。
- `inputText`、普通 click、Intent、屏幕截图为 `SENSITIVE`，shell 为 `DESTRUCTIVE`，由执行器在真正调用前确认，模型无法关闭确认。
- 普通 click 可由用户授予“此页面的低风险导航”，仅在同一任务、App、窗口和页面指纹内有效。输入、Intent、shell、提交型动作永远不进入页面授权。
- 无文本、无语义、仅图标、自绘、角色异常或存在点击节点重叠时，按敏感动作逐次确认。
- 一次性确认绑定 tool call、App、窗口、页面指纹、节点和参数，30 秒失效且只消费一次；界面变化后返回 stale，Agent 必须重新观察。
- 通知访问是 Android 长期权限；把通知发送给模型则按当前任务、模型、App 范围、回看时间和最大条数授权。更宽的后续查询必须再次确认，监听重连后旧授权失效。
- 确认输入密码时仅显示掩码；Intent 显示 action/data/type/app/extras；shell 显示完整命令和 App UID 限制。

普通 App 无法读取其他 App 私有数据、静默修改受保护系统设置、获得 ADB 权限或绕过 Android 安全机制。Aurai 不启动 `VpnService`，可以和手机已有第三方 VPN 共存。受保护窗口拒绝截图时不会尝试绕过。

## vivo / OriginOS 使用

1. 安装 `build/app/outputs/flutter-apk/app-debug.apk`，并允许该安装来源。
2. 在 Aurai 的“设置 → 模型服务”选择 OpenAI 或 DeepSeek，并填写各自独立保存的 API 密钥、模型和地址。
3. 允许 Aurai 联网。网络诊断不需要定位，也不读取 Wi-Fi SSID。
4. 首次任务允许通知，使 Agent 切换到其他 App 后仍显示运行状态和停止入口。若拒绝通知，只有 Aurai 无障碍胶囊在线时才会继续跨 App 任务。
5. 当任务第一次需要控制其他 App，点“去开启”，在 OriginOS 的无障碍设置中启用 Aurai，然后返回。任务会自动继续。
6. 当任务确实需要读取其他 App 的通知时，Aurai 会说明原因并打开“通知使用权”；在列表中允许 Aurai 后返回。它与“允许 Aurai 自己发通知”是两项不同权限。
7. 建议在 OriginOS 电池管理中允许 Aurai 后台运行。若系统仍终止任务，中断卡会同时提供 Aurai 应用设置入口和“继续任务”。

无障碍服务运行任务时会显示小型“Aurai 运行中”胶囊，始终提供“返回 Aurai”和“停止”。敏感操作会在目标 App 上方展开确认卡；不需要额外的悬浮窗权限。

## 下一步

下一步最值得增加的是可选 Shizuku 执行 adapter。普通 App 权限已经能完成网络黑盒探测；Shizuku 可在用户明确授权后补充系统网络配置、进程和日志等更深的只读证据，同时仍由同一工具 schema、capability 和风险确认层约束。
