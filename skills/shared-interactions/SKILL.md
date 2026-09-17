---
name: shared-interactions
description: 在 Aurai 中设计、创建和参与持续交互卡片。适用于多人投票、报名选择、隐藏出招、答题计分及多轮协作；用共享状态、提交、结算规则和视图组合玩法。
---

# 共享交互消息

这是 Aurai 技能库中的公共使用指南，供人和 AI 协作维护。阅读后直接调用交互消息工具；不需要运行技能脚本。工具的参数 schema 是当前版本能力的依据。

## 如何选择场景

- 投票、活动报名、时间偏好：一人一份当前选择，可改选，分布组件自动汇总。
- 猜拳、双方秘密决策、同时揭晓答案：先隐藏提交，人数达到条件后统一结算。
- 小测验、连续答题：结算规则判断值并更新共享分数，下一轮保留总分。
- 多人一致确认：收集每人选择，规则判断是否达到人数或是否一致，再给出下一步。
- 个人分支故事：已有 update/nextState 足够，按参与者独立保存进度。

这些是组合方式，不是固定玩法清单。一次性问问题优先直接提问。当前输入主要为按钮提交 JSON 值，展示支持文字、指标和选择分布；拖拽、实时动画、自由输入表单尚不属于这套原生卡片能力。

## 一张共享卡片如何定义

sendInteractiveMessage 默认发送到当前会话，也可传 conversationId 发送到自己仍是成员的指定会话，无需切换页面。通过 searchConversations/listGroupChats 获取目标会话，不要让用户填写 ID。当前私聊内的卡片插入本次回复；跨会话发送的卡片作为目标会话中的独立消息，不插入当前回复。跨会话读和点击也不必切换会话。

1. title/body 写参与者能理解的目的和规则；正文支持真实换行。
2. buttons 中每个按钮都有 id、label、action、repeatable。共享选择使用 action=submit、value；icon=none 可以不带图标。按钮 ID 是内部引用。
3. interaction.initial 是初始共享数据，roundInitial 是每轮重置的数据；下一轮保留其他共享字段。
4. completion 是完成条件，默认持续收集。onComplete 的规则按顺序运行，每条 set 合并共享字段，后一条能读取前一条写入的 state。应用负责事务结算，同一轮不会重复计分。
5. views 只负责展示已允许读取的状态，不能代替结算规则。type=text 或 metric 使用 value 表达式；type=distribution 汇总当前轮 submit 选项，unit 可写“票”“人”。用 when 决定何时展示。

buttonColumns 控制按钮排列：省略或 1 为单列，2 为双列等宽网格，按从左到右、从上到下排列；奇数个按钮的最后一个保持半宽。短选项较多的投票、答题优先使用 2，长文案操作使用 1。布局不改变点击即提交、权限或计票规则。更新消息、命名状态和 AI 回调结果均可指定；省略时保留当前布局。

allowChange 控制同一人能否更改本轮提交，与按钮 repeatable 不同。默认允许；秘密出招通常设 false。reveal=immediate 立即公开，onComplete 等完成或关闭后揭晓。

participation.visibility 控制个人选择；summaryVisibility 控制汇总，各支持 public/private/afterClose。reveal 不会覆盖这两项设置。共享 state 可能包含选择及派生统计，只有揭晓且个人/汇总均可见时才提供。若想结算后公开，使用 public 配合 reveal=onComplete；不要用 private 又期待结束后自动显示。

指定玩家时，从已有会话成员信息取得 actor ID，填写 interaction.actors；不要让用户填 ID。省略 actors 允许任何人参与；completion=count==2 意味着首先提交的两人，并不会自动限定为“我和用户”。

## 单选与多选列表

需要先勾选、再确认时，在一个 submit 按钮上配置 selection。单选 mode=single 显示圆圈，多选 mode=multiple 显示方框；选项列表始终单列，buttonColumns 只控制普通按钮。示例：

```json
{"id":"vote","label":"投票","action":"submit","repeatable":false,"icon":"none","selection":{"mode":"multiple","minSelections":1,"maxSelections":2,"options":[{"id":"a","label":"南浔","value":"nanxun"},{"id":"b","label":"宜兴","value":"yixing"},{"id":"c","label":"安吉","value":"anji"}]}}
```

卡片同时提供 interaction，例如 {"allowChange":true,"views":[{"type":"distribution","unit":"人"}]}。single 固定选择一项；multiple 默认至少一项，最多全部选项，也可配置数量范围。选择时仅暂存，点击投票才提交。提交后保留只读选项，allowChange 允许通过“修改选择”改选。一个人一次提交，多选分布每个选项各记一人，百分比之和可以超过 100%。

AI 调用 clickInteractiveMessage 时，buttonId 为 vote，value 传选项 ID：单选传 "a"，多选传 ["a","c"]；不要传配置中的业务值。系统将选项解析成配置值，单选的 submission.value 为该值，多选为值数组，selections 保留选项 ID、名称和值。历史和回调会记录实际所选，沿用原有可见性规则。

## 人和 AI 如何参与

先 readInteractiveMessage，依据自己的 interactionView 看阶段和提交情况，再用当前 revision、participantRevision、messageId 和目标 buttonId 调用 clickInteractiveMessage。身份由运行时确定，口头说“我投某项”不会记录选择。

读别人时，participantId 仅改变只读 perspective；不能用对方的状态冒充对方提交。隐藏阶段看不到别人选择，这是规则生效，不是工具故障。已提交且不可修改时等待，不要循环重复点击或刷读。

结算后点击卡片的 nextRound 按钮推进；应用清空本轮提交并应用 roundInitial。陈旧状态错误后重新读，判断是否仍该执行；不要把上一轮的选择盲目补交到下一轮。

修改共享定义使用 updateInteractiveMessage，只能改自己发出的卡片。先读 definition，再传 revision、title、body、buttons 和要改的字段。参与记录和共享运行态保留；修改 initial 不会重置当前分数，已完成的一轮不会因编辑再次结算。

作者可通过 participation.closed=true 结束收集。关闭会揭晓已有提交，但只有 completion 成立才执行 onComplete；人数不够时不要声称已经算出双方胜负。若希望“关闭时结算”，让 completion 显式读取 closed。是否需要修改、结束或下一轮入口，要与玩法说明一致。

## 表达式速查

常量、数组、普通对象可直接写；{ref:"state.score"} 读取路径；{op:"add",args:[...]} 执行运算。含 ref/op 作为业务键的数据用 {literal:...} 包起来。

支持 eq/ne、gt/gte/lt/lte、and/or/not、if、add/subtract、sum、length、values、get、concat、map/filter。if/and/or 按需求值。map/filter 的 args 是 [列表,表达式]，当前项通过 item/index 读取；嵌套遍历会覆盖这两个绑定。

结算上下文包括 state、submissions、choices、submittedCount、round、phase、closed。choices 按本轮首次提交顺序排列，每项含 actorId/name/buttonId/label/value。不要把这个顺序当作固定玩家身份。按 ID 找人可用 get(submissions, actorId)。

视图上下文包括 submitted、self、completed、revealed、summaryVisible、round、phase、closed、submittedCount，以及可见时的 state/distribution/choices/submissions。读取结算结果的组件通常设置 when={ref:"completed"}；不要在对方未提交时索引 choices.1。规则和视图是 JSON 表达式，不是 JavaScript、Dart 或 Python。

## 示例：公开选择并显示分布

下面是完整 sendInteractiveMessage 参数，可直接按主题改标题、正文和选项。completion=false 持续收集，作者需要结束时更新 closed。

```json
{
  "title": "周末一起做什么",
  "buttonColumns": 2,
  "body": "选你更想参加的一项，可以修改选择。",
  "buttons": [
    {
      "id": "walk",
      "label": "散步",
      "action": "submit",
      "value": "walk",
      "repeatable": true,
      "icon": "none"
    },
    {
      "id": "movie",
      "label": "看电影",
      "action": "submit",
      "value": "movie",
      "repeatable": true,
      "icon": "none"
    },
    {
      "id": "cook",
      "label": "一起做饭",
      "action": "submit",
      "value": "cook",
      "repeatable": true,
      "icon": "none"
    }
  ],
  "participation": {
    "visibility": "public",
    "summaryVisibility": "public"
  },
  "interaction": {
    "completion": false,
    "allowChange": true,
    "reveal": "immediate",
    "views": [
      {
        "type": "distribution",
        "unit": "票",
        "when": {
          "op": "or",
          "args": [
            {
              "ref": "submitted"
            },
            {
              "ref": "closed"
            }
          ]
        }
      }
    ]
  }
}
```

## 示例：两人隐藏选择、按关系表结算

下面同样是完整发送参数。规则使用关系表，没有游戏专属动作。示例对前两位提交者开放；指定两人时先加入 actors 并改正文。总轮数保留，本轮结果在下一轮清空。

```json
{
  "title": "一起猜拳",
  "body": "前两位参与者各出一招，双方提交后揭晓。每轮只能提交一次。",
  "buttons": [
    {
      "id": "rock",
      "label": "石头",
      "action": "submit",
      "value": "rock",
      "repeatable": true,
      "icon": "none"
    },
    {
      "id": "scissors",
      "label": "剪刀",
      "action": "submit",
      "value": "scissors",
      "repeatable": true,
      "icon": "none"
    },
    {
      "id": "paper",
      "label": "布",
      "action": "submit",
      "value": "paper",
      "repeatable": true,
      "icon": "none"
    },
    {
      "id": "again",
      "label": "下一轮",
      "action": "nextRound",
      "repeatable": true,
      "icon": "reset"
    }
  ],
  "participation": {
    "visibility": "public",
    "summaryVisibility": "public"
  },
  "interaction": {
    "initial": {
      "beats": {
        "rock": "scissors",
        "scissors": "paper",
        "paper": "rock"
      },
      "roundsPlayed": 0
    },
    "roundInitial": {
      "result": null
    },
    "allowChange": false,
    "reveal": "onComplete",
    "completion": {
      "op": "eq",
      "args": [
        {
          "ref": "submittedCount"
        },
        2
      ]
    },
    "onComplete": [
      {
        "set": {
          "result": {
            "op": "if",
            "args": [
              {
                "op": "eq",
                "args": [
                  {
                    "ref": "choices.0.value"
                  },
                  {
                    "ref": "choices.1.value"
                  }
                ]
              },
              "平局",
              {
                "op": "if",
                "args": [
                  {
                    "op": "eq",
                    "args": [
                      {
                        "op": "get",
                        "args": [
                          {
                            "ref": "state.beats"
                          },
                          {
                            "ref": "choices.0.value"
                          }
                        ]
                      },
                      {
                        "ref": "choices.1.value"
                      }
                    ]
                  },
                  {
                    "op": "concat",
                    "args": [
                      {
                        "ref": "choices.0.name"
                      },
                      "获胜"
                    ]
                  },
                  {
                    "op": "concat",
                    "args": [
                      {
                        "ref": "choices.1.name"
                      },
                      "获胜"
                    ]
                  }
                ]
              }
            ]
          },
          "roundsPlayed": {
            "op": "add",
            "args": [
              {
                "ref": "state.roundsPlayed"
              },
              1
            ]
          }
        }
      }
    ],
    "views": [
      {
        "type": "text",
        "when": {
          "ref": "completed"
        },
        "value": {
          "ref": "state.result"
        }
      },
      {
        "type": "metric",
        "label": "已完成轮数",
        "when": {
          "ref": "completed"
        },
        "value": {
          "ref": "state.roundsPlayed"
        }
      }
    ]
  }
}
```

给玩法扩展计分时，把稳定的参与者 ID 对应分数放在 initial，结算时更新，别放进 roundInitial。多人猜拳需先定义三种出招同时出现时如何处理，不能把两人规则直接当成多人规则。报名容量、自动定时结束和自由文本输入也不能只靠文案宣称已实现。

固定轮数自动结束目前没有内建保证：例如“三轮猜拳”，第三轮结算后 nextRound 仍可点击；作者需要随后更新 closed，不能只改文案就承诺自动止于三轮。reveal=onComplete 在收集阶段会隐藏整个共享 state，所以示例保留累计轮数，但只在结算后展示。


## 点击后由 AI 处理

按钮设置 notifyAi=true 后，应用先保存这次操作，再向创建者派发回调。触发者看到等待状态，仅触发回调的按钮暂时锁定，其他按钮和参与者仍能操作；后续改变卡片状态的操作会使旧回调失效，普通可重复打开的链接不影响回调。纯本地规则和固定结果不必开启回调。

收到 requiresResult=true 的事件后，处理结果用 updateInteractiveMessage 返回：提供 messageId、当前 revision、callbackEventId=eventId，以及 title/body/buttons。结果仅替换触发者在原卡片上的呈现；此调用不带 interaction/participation/states。即使内容无需变化，也要提交该呈现以确认完成，单独发一句聊天文字不能结束等待。

回调完成和结果写回在同一事务中保存；同一事件重复完成不会再次覆盖。失败后用 retryInteractiveCallback(messageId, callbackEventId) 重试自己的事件，或由用户点击卡片重试；不要再次调用原按钮来重试。下一轮或共享定义已更新时，旧回调会失效，读取最新状态继续。

重试复用同一事件，不重复按钮的本地计票或状态变化。AI 执行的外部工具不因此自动获得幂等性：若之前已取得随机结果或完成外部操作，复用已有结果，不要重新抽取或重复执行。模型结束但没有提交卡片结果，仍视为未完成。
