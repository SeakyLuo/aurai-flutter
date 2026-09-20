# 工具调用失败核查（2026-09-20）

## 范围与结论

读取手机当前保留的全部 4,109 条工具调用，发现 324 条失败、拒绝、取消或缺失结果记录；另发现 3 条 shell 调用虽然工具层返回 success，但命令退出码非零。仅覆盖当前数据库保留的历史，不包含已删除记录。

- 本次未修改手机数据、未重放工具、未构建或安装 App。
- 手机数据库已为 v38；旧字段缺失和快捷回复唯一约束问题已核实结构修复。
- “代码已修复”不等同于已在手机安装验证；本次最终执行 `dart analyze lib`，结果无问题。
- 历史空值异常缺少堆栈，不能保证全部由同一原因导致；下表保留这项不确定性。

## 分类汇总

| 状态 | 历史记录数 |
|---|---:|
| 无需修复 | 13 |
| 已有修复（代码） | 48 |
| 证据不足 | 4 |
| 无需放开限制 | 42 |
| 无需兼容错误参数 | 148 |
| 本次修复 | 4 |
| 无需修改工具框架 | 5 |
| 已有修复（手机结构已确认） | 14 |
| 本次修复（相关路径） | 31 |
| 相关路径已修正，历史根因未唯一确认 | 15 |

## 全部失败分类明细

| 状态 | 问题 | 数量 | 涉及工具 | 结论 |
|---|---|---:|---|---|
| 无需修复 | 用户拒绝或取消 | 9 | act、executeAndroidScript、goBack、requestDocumentFolder | 保留审批和取消行为，不自动重试。 |
| 无需修复 | 网页服务错误或读取范围限制 | 4 | readWebPage | 404/500属于远端响应；网页工具当前只处理指定大小的HTML/纯文本，不自动扩大范围。 |
| 已有修复（代码） | 工具未加载或被淘汰 | 23 | clickInteractiveMessage、clickUiElement、executeAndroidScript、installSkill、listGroupChats、listMemories、observeDevice、openSettings、readGroupChat、readGroupMessages、readInteractiveMessage、readSkill、readWebPage、searchMessages、searchWeb、wait | 已调用工具保留至本次运行结束；存在但未公开的工具会载入下一轮，并明确此次未执行。 |
| 证据不足 | 未保存失败正文 | 4 | executeAndroidScript、getNotifications、sendGroupMessages | 进程中断记录或通知结果按策略不持久化，现有记录无法还原原因。没有重放外部操作。 |
| 无需放开限制 | 对象、成员身份或可见性校验 | 42 | clickInteractiveMessage、readAiContact、readAttachment、readGroupChat、readGroupMessages、readHtmlMessage、readInteractiveMessage、sendConversationMessage、sendGroupMessage、sendQuickReply | 保留权限和阶段校验；先读取有效对象/当前版本。临时成员资料可使用对应群成员或本人资料工具；正式联系人管理要求先保存。readGroupChat另已有缺少id字段的明确参数提示。 |
| 已有修复（代码） | 旧版跨群或私聊发群消息限制 | 21 | sendGroupMessage、sendGroupMessages | 当前发送路径支持指定已加入的目标群；旧 sendGroupMessages 已被单条工具替代。 |
| 无需兼容错误参数 | 模型调用参数或交接流程不符合定义 | 148 | listGroupChats、readGroupMessages、requestDocumentFolder、searchTools、sendGroupMessage、sendGroupMessages、sendHtmlMessage、sendInteractiveMessage、sleepGroupChat | 包含字符串null、对象被二次序列化、缺字段、错误枚举/类型、JSON语法、nextState引用不存在，以及重复人工交接。保留严格校验，按工具schema修正调用，不做猜测转换。 |
| 本次修复 | 发送交互卡缺少独立 buttons 参数 | 1 | sendInteractiveMessage | 原调用把按钮文本混入正文；新增必填字段及顶层类型校验，拒绝错误输入并提供具体字段名。 |
| 无需修改工具框架 | 临时脚本错误、退出或超时 | 5 | executeAndroidScript | 包含Java字符串直接使用JS正则replace、数组越界、脚本退出及超时；应修当次脚本或拆分任务，不能盲目重放已有副作用。 |
| 已有修复（手机结构已确认） | 交互历史缺少 before_json | 11 | readInteractiveMessage | 升级迁移已存在，手机数据库 v38 已包含该字段。 |
| 本次修复 | 更新交互卡缺少 messageId 却抛空值异常 | 3 | updateInteractiveMessage | 三条原始参数均缺 messageId；工具边界现在提示缺少必填字段，不进入存储操作。 |
| 本次修复（相关路径） | 睡眠调用返回 AgentCancelled 错误 | 31 | sleepGroupChat | 关闭自动接话时允许 seconds=-1 结束任务；定时睡眠说明需恢复接话。真实取消返回 cancelled。历史31条中可能同时包含真实停止，不能全部算成程序故障。 |
| 已有修复（手机结构已确认） | 快捷回复唯一约束过窄 | 3 | sendQuickReply | 手机现有唯一键为原消息、参与者、表情类型，允许同一人使用不同表情。 |
| 已有修复（代码） | 引用消息 senderName 未初始化 | 4 | sendGroupMessage | 群内发送和跨群发送构造引用时均已补齐名称。 |
| 相关路径已修正，历史根因未唯一确认 | 群发送或睡眠空值异常 | 15 | sendGroupMessage、sleepGroupChat | 历史没有堆栈。工具现在绑定创建时的调度器，旧任务结束后返回取消，不再临时取可能已清除的调度器；已为内部异常补记堆栈。不能证明这些历史记录全是同一原因。 |

## 本次代码变更

1. `interactive_message_tool.dart`：在调用业务逻辑前校验实际模型输入的必填字段和顶层类型，修复缺少 messageId/buttons 导致的不透明空值异常。不会补造字段或转换字符串对象。
2. `group_sleep_recovery.dart` / `group_dispatcher.dart`：已关闭自动接话的成员在临时唤醒后可以用 seconds=-1 结束本次任务；定时唤醒仍受关闭状态约束。
3. `group_sleep_tool.dart` / `group_message_tool.dart`：正常任务取消返回 cancelled，避免被记成普通失败。
4. `group_run_tools.dart`：群发送与睡眠工具固定绑定所属运行的调度器，结束的调度器不再接收旧任务操作。从会话运行文件提取同一职责的工具构造，保持文件不超过800行。
5. `execution_log.dart`：为上述工具的内部程序异常记录类型与堆栈，不记录参数内容；业务参数错误仍返回可读说明。

## 无需修改的命令失败

另有3条 shell 命令退出码为127、127、1：手机没有 python3；一次后续拼接命令试图执行“-”。这是当次命令与手机环境不匹配，工具已返回退出码和stderr。未在手机安装Python，也未重放命令。

## 证据边界

未保留错误正文的4条记录（含通知结果不持久化）不能判断是否为应用缺陷。群发送/睡眠15条历史空值错误虽已处理对应运行绑定风险，但缺少原始堆栈，不能宣布历史根因完全确认。后续若出现同类内部异常，新日志将带工具名、调用编号、异常类型与堆栈，便于精确定位。

## 原因分组（覆盖324条）

| 工具 | 原因 | 次数 |
|---|---|---:|
| act | Operation was not approved | 2 |
| readWebPage | 网页内容超过 2MB，请换用更具体的页面 | 1 |
| readWebPage | 网站返回错误（500） | 1 |
| readWebPage | 目前只支持 HTML 网页和纯文本，不支持 PDF 或其他文件 | 1 |
| openSettings | Tool is not loaded for this turn. Use searchTools first. | 1 |
| observeDevice | Tool is not loaded for this turn. Use searchTools first. | 4 |
| clickUiElement | Tool is not loaded for this turn. Use searchTools first. | 1 |
| goBack | Operation was not approved | 1 |
| wait | Tool is not loaded for this turn. Use searchTools first. | 1 |
| executeAndroidScript | Operation was not approved | 4 |
| executeAndroidScript | Tool is not loaded for this turn. Use searchTools first. | 2 |
| executeAndroidScript | {} | 2 |
| readAiContact | Bad state: 这是临时群成员，请先在通讯录中保存 | 1 |
| sendGroupMessages | 群内只能向当前群发送消息 | 10 |
| requestDocumentFolder | 当前工具已有用户等待流程，或已有问题未处理，不能再添加人工交接。此次动作尚未执行，请移除 userAction 或先处理已有问题。 | 1 |
| requestDocumentFolder | {'cancelled': True} | 2 |
| sendGroupMessages | {} | 1 |
| sendGroupMessages | 请先确认要调整哪个群聊 | 1 |
| sendGroupMessages | mentionIds 必须是成员 ID 数组；不 @ 成员请省略或传 [] | 1 |
| sendGroupMessage | 群内只能向当前群发送消息 | 8 |
| sendGroupMessage | participation 必须是 unchanged、paused 或 active | 6 |
| sendGroupMessage | 每条消息必须包含 text 字符串 | 15 |
| sendGroupMessage | message 类型错误：收到 String，需要 JSON 对象或 null，不能是序列化后的字符串或数组。请直接传 "message":{"text":"你好"}，不要对 message 再做 JSON 编码 | 36 |
| sendInteractiveMessage | type 'Null' is not a subtype of type 'List<dynamic>' in type cast | 1 |
| sendGroupMessage | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 51 |
| sendGroupMessage | groupId 必须是实际群 ID 或 JSON null；不要传字符串 "null"。当前群请用 "groupId":null | 11 |
| sendGroupMessage | 缺少 groupId；发给当前群请传 "groupId":null，不要省略 | 3 |
| sendInteractiveMessage | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 1 |
| searchTools | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 2 |
| sleepGroupChat | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 7 |
| sendGroupMessage | sendGroupMessage 只能向当前群发送；请将 groupId 设为 JSON null（不是字符串）。如用户要求发送到其他会话，请使用 sendConversationMessage | 1 |
| sendHtmlMessage | 请提供 title、html 字符串和 height 整数；width 使用整数或 JSON null | 3 |
| listGroupChats | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 1 |
| sendGroupMessage | 私聊中此工具仅调整接话状态，不能发送群消息 | 2 |
| readGroupMessages | userAction 必须是具体的用户操作说明；不需要用户接手时请传 JSON null，不要传字符串 "null"。此次工具尚未执行，请修正参数。 | 2 |
| sendGroupMessage | 目标群聊不存在 | 2 |
| getNotifications | {'contentRetention': 'task_only'} | 1 |
| readHtmlMessage | HTML 消息不存在或已撤回 | 4 |
| sendInteractiveMessage | nextState 必须指向已定义的状态 | 1 |
| executeAndroidScript | Script process exited; verify any side effects before retrying | 1 |
| readInteractiveMessage | 交互消息不存在或已撤回 | 3 |
| clickInteractiveMessage | Tool is not loaded for this turn. Use searchTools first. | 1 |
| executeAndroidScript | Script timed out after 90 seconds. Earlier side effects are not rolled back; observe before retrying. | 1 |
| readInteractiveMessage | 数据库缺少 before_json | 11 |
| sendInteractiveMessage | invalid_tool_arguments | 4 |
| readInteractiveMessage | 这条消息尚未公开其他参与者的选择 | 1 |
| sendGroupMessage | message 对象缺少 text 字段。示例："message":{"text":"你好"}；仅发送图片时 text 传空字符串 | 1 |
| updateInteractiveMessage | Null check operator used on a null value | 3 |
| sleepGroupChat | Instance of 'AgentCancelled' | 31 |
| clickInteractiveMessage | 本轮已结束，请查看结果 | 1 |
| readInteractiveMessage | 你无权查看这条交互消息 | 16 |
| listGroupChats | Tool is not loaded for this turn. Use searchTools first. | 2 |
| sendConversationMessage | 会话不存在或你无权访问 | 2 |
| readGroupMessages | 只能读取自己当前所在群的消息 | 3 |
| readGroupMessages | Tool is not loaded for this turn. Use searchTools first. | 3 |
| readInteractiveMessage | 消息不存在或你无权访问该会话 | 3 |
| sendQuickReply | Bad state: 消息不存在或不可见 | 3 |
| sendQuickReply | 快捷回复唯一约束冲突 | 3 |
| sendGroupMessage | LateInitializationError: Field 'senderName' has not been initialized. | 4 |
| sleepGroupChat | Null check operator used on a null value | 9 |
| readAttachment | 附件不存在或已删除 | 1 |
| executeAndroidScript | EvaluatorException: The choice of Java method java.lang.String.replace matching JavaScript argument types (object,string) is ambiguous; candidate methods are:  … | 1 |
| sendGroupMessage | Null check operator used on a null value | 6 |
| sendGroupMessage | invalid_tool_arguments | 1 |
| readInteractiveMessage | Tool is not loaded for this turn. Use searchTools first. | 1 |
| readWebPage | 网站返回错误（404） | 1 |
| readGroupChat | Tool is not loaded for this turn. Use searchTools first. | 1 |
| readGroupChat | 群聊不存在或你不是当前成员 | 2 |
| installSkill | Tool is not loaded for this turn. Use searchTools first. | 1 |
| readSkill | Tool is not loaded for this turn. Use searchTools first. | 1 |
| listMemories | Tool is not loaded for this turn. Use searchTools first. | 1 |
| searchMessages | Tool is not loaded for this turn. Use searchTools first. | 1 |
| executeAndroidScript | EcmaError: TypeError: Cannot set property "2.0" of undefined to "5" (device-script#6) | 1 |
| executeAndroidScript | Script timed out after 180 seconds. Earlier side effects are not rolled back; observe before retrying. | 1 |
| readWebPage | Tool is not loaded for this turn. Use searchTools first. | 1 |
| searchWeb | Tool is not loaded for this turn. Use searchTools first. | 1 |

## 后续：数据读取授权

根据后续要求，群资料、群历史、消息、附件、交互消息和 HTML 读取已接入现有工具授权。当 AI 无权读取而本地用户有权查看时，支持允许一次、当前会话允许和始终允许。读取仍按用户可见范围执行，返回结果标明用户视角；不扩大写入权限。上述 42 条历史失败包含对象不存在、写入和阶段限制，不能全部归为授权问题。
