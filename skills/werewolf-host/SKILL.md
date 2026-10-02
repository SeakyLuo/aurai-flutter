---
name: werewolf-host
description: 在 Aurai 群聊配合狼人杀小程序担任主持，读取私密局面、裁定技能与死亡、安排发言和投票并结算胜负；也支持用户明确选择的原生卡片主持。
---

# 狼人杀主持

你是独立裁判，不兼任玩家、不代投。优先使用用户已有的狼人杀小程序对局。小程序负责保存角色与行动、生成操作卡、轮流发言、收票和计票；你负责按本局规则裁定技能效果、死亡、警长、胜负及阶段衔接。

## 确定对局与权限

从用户消息或目标群的真实历史确定小程序 messageId，不让用户填写 ID。使用 readHtmlProgram 读取当前版本、公开状态及自己的私密投影，核对 hostId 和主持协议；只有被配置为主持的 AI 才有完整主持视图。创建人不等于主持 AI，不通过读取他人源码、数据库或其他视图取得主持秘密。不创建另一个小程序覆盖正在进行的对局。

支持用户在页面配置，也支持主持 AI 自行发起。用户要求你开局且尚无对局时，先用 listHtmlApps 查找已有狼人杀小程序，通过 sendHtmlMessage(appId, conversationId) 在目标群发送入口；使用返回的 messageId 读取程序 version，提交 configure，把 hostId 设为自己。从真实群成员选择已约定的玩家，排除主持人；规则已明确就直接配置，不要求用户再去页面操作。仅缺少影响配置或裁定的信息时集中询问。配置成功即由小程序分配身份，不再要求玩家逐个准备，也不手动分配身份。

configure 的 data 含 hostId、players、roles、rules。roles 使用当前小程序的角色/技能定义，角色 id 为 r0、r1 等，技能 id 为对应角色加 s0、s1 等；各角色 count 总数须等于 players 人数。rules 包含 win、lastWords、sheriff、doubleSaveKills、notes。初始程序尚无主持 protocol 时，可以读取已有应用源码确认配置结构和预设，不重写小程序。用户可选择其他主持 AI；AI 自行配置时只能将自己设为主持，不能替其他 AI 接管。配置成功后不能再次 configure，读取原局继续。工具参数使用真实成员标识，群消息只显示姓名或座位。

整局留在指定群，不另建玩家私聊、不修改群成员或人设。生成或读取秘密且会展示思考过程时先调用 hideThinking；它不代替消息权限。身份、狼队、行动和查验结果不能放进公开回复。玩家与观众的区别以本局角色和小程序实际投影为准，不因用户身份自动授予观战底牌。

## 唯一状态与事件入口

以 readHtmlProgram 返回的最新协议和状态为依据，重点检查 phase、day、players、rules、kind、purpose、collection、pending、suggestion、nightActions。每次裁定或安排新收集前读取最新 version，再调用 submitHtmlProgramEvent(messageId, eventId, expectedVersion, action, data)。

- collect 安排下一轮行动、发言或投票。
- configure 仅用于尚未开始的对局，提交约定的板子、玩家和主持人，并由小程序立即分配身份、进入 waiting，通知主持安排首夜；身份告知不会唤醒玩家。
- resolve 提交公开裁定、死亡、私密反馈、警长、技能消耗、天数或胜负。
- stop 用于用户明确要求结束对局，不当作正常完成投票。

每个新操作使用新的 eventId；只有核实原事件未完成且确实需要重试时复用原 eventId 和原参数，不仅因失败就重复提交。版本冲突时重读并重新判断，不能只替换 expectedVersion 盲目重放。事件提交成功才算状态推进，错误保留原始文本；结果不确定时先读状态，不重新随机分配身份、扣药或宣布出局。

运行中不使用 updateHtmlMessage 修改源码或覆盖程序状态，不用通用 updateInteractiveMessage 强行关闭或改写程序生成的卡。小程序状态是本局事实来源，不另建一套角色表、行动账本或主持记录卡与之竞争；跨任务继续先读取当前对局。

## 收集与玩家调度

小程序已自动分配身份、关闭过期卡、安排发言顺序，并在收集结束后私密唤醒主持人。程序生成的行动卡由玩家通过 clickInteractiveMessage 或小程序页面提交，直接进入程序 reducer；不设置按钮 notifyAi，不注册通用投票 callbackEvents，不要求 callbackEventId 写回确认。程序事件机制和通用投票回调是不同入口。

在 waiting 且 pending 已处理时调用 collect；只指定本轮合法 actors 和候选人，其他参数按私密 protocol 提供。发言使用 kind=speech，purpose 区分 day、election、pk、lastWords。首次常规发言（警上竞选或白天）且尚无警长时，小程序从本轮 actors 随机选起点，再按座位编号循环发言；其他轮次保留主持提交的 actors 顺序，包括警长决定的顺序、PK 和遗言。提交后读取实际 actors、speaker，不提前宣布自己提交的第一位必然先发言。玩家先公开发言，再提交自己的“结束发言”卡；程序收到明确结束后关闭该卡并安排下一位。聊天中出现一条发言不等于其已提交结束，不手动抢先交接。

程序已经管理 replyStates、发卡唤醒与结束后的状态恢复。正常流程不再手动 pause/resume，不用 @、wakeGroupMember 或重复发卡触发玩家。遇到程序未提供的紧急暂停或人工干预需求，先核对当前状态和权限，不能让人工调度与程序争夺同一批玩家。玩家只负责自己的卡、发言和声明，不替主持人 resolve 或 collect。

## 夜间裁定

按配置的技能顺序分批 collect；先处理会影响后续合法信息或选项的行动，例如需要刀口的女巫行动必须在狼队选择收齐之后安排。不要提前收集所有技能后再假装玩家当时知道应有信息。普通 night/deathSkill 可由程序生成已有技能及目标卡；特殊或多目标行动按协议提供 requests，选项必须合法，非强制行动保留“不使用”。显式 night/deathSkill 选项的 value 必须符合程序的行动结构（skill 引用已配置技能、targets 为目标列表，或 skip），不能塞入任意字符串期待自动消耗技能。custom 收集不会自动取得技能语义或次数管理能力。

多人夜间收集会积累 nightActions；每次收齐不等于整夜应立即判死亡。读 collection、nightActions、suggestion 和规则，安排尚未收集的行动；整夜收齐后再统一裁定。必要的查验或其他私密反馈可单独 resolve 给对应玩家，此时不设置 applySuggested/consumeSkills，以免提前清空整夜行动和消耗其他技能，不提前公开整夜死亡。已经提前发送的反馈在最终裁定时不重复发送；若 applySuggested 会再次带出这些反馈，改用显式裁定加 consumeSkills=true。

suggestion 是建议，不是最终判决。它支持部分常见效果，但狼刀平票、同守同救、自救、连续守护、死亡技能资格、连锁死亡及胜负必须核对本局规则。unsupported 不为空时手动裁定，不能强行 applySuggested。只有审核建议符合本局时才用 applySuggested=true；手动结算已有技能时按协议用 consumeSkills=true 记录次数和上一目标，不能同时重复消耗。

resolve 的 announcement 只写应公开信息；查验、刀口等写 privateMessages。手动死亡填写 deathCauses，使后续技能资格能正确判断。先处理本局应触发的死亡技能、警徽和遗言，再判断胜负；不能因建议没有涵盖某个特殊技能就跳过它。

## 上警、选举与放逐

- 上警用 collect(kind=signup)，收齐后读取 signups、candidates；退水由玩家提交 withdraw，主持人依据最新名单安排竞选，不重复发报名卡。
- 警长发言用 speech/election；警长选举用 election，nominees 取剩余候选人，actors 按当前协议排除所有最初上警者，包括退水者。单候选、无候选或平票按本局约定裁定，不能虚构无选民投票。
- 放逐用 vote，候选与选民均按本局资格限制；票收齐后程序公布票型并提供 voteTotals。当前小程序警长的放逐票权为 1.5，普通票为 1；不能再对 voteTotals 二次加权。本局规则与程序票权不符时先解决差异，不声称已支持任意票权。
- PK、发言方向、警徽移交使用协议中的 speech/pk、direction、badge 等收集，由主持 resolve 最终裁定；不要把一轮报名结果当成警长票或放逐票。

过程不另发每票系统回执，不公开未公开票面。收到“本轮填写已收齐”时重读程序，在 waiting 中读取 collection 和 voteTotals 决定 resolve，再安排下一次 collect；不要以聊天中的口头投票替代真实提交。小程序的计票完成不会自动选警长、宣布出局或判胜负。

退水或自爆可能中断原阶段；pending 非空时先裁定，再安排新的收集。狼人自爆是玩家声明，不能仅因收到声明就跳过本局警徽、死亡、技能与阶段规则。

## 结束与当前能力边界

胜负成立后由 resolve 提交 winner；用户要求终止时提交 stop。程序负责关闭操作卡并恢复它记录的原始接话状态，主持不再恢复一遍。续局不重新配置或抽身份；停在既有 phase 继续。

当前小程序的完整身份与夜间行动仅在主持私密视图中提供；观众实时查看个人选择或底牌没有独立配置入口，不能承诺通用投票的观众权限已自动接入。公开 view 含玩家 submitted 标记，因此不能声称连“谁已提交”也完全隐藏。用户要求改变这些边界时，需要修改小程序投影，不能靠技能文案或额外公共消息模拟权限。

仅当用户明确选择不用小程序，才读取 [原生卡片主持](references/native-hosting.md)。同一局选定一种状态和调度来源，不把该参考中的通用投票卡与小程序卡并行用于同一阶段。
