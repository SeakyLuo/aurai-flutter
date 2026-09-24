# DMX 请求转换

这两个脚本是 Aurai「请求转换」编辑器使用的函数体，接收 `request`，返回 `{path, body}`。

在 DMX 供应商的「请求转换」中，分别选择对应模型并配置：

| 模型 | 协议 | 脚本 |
| --- | --- | --- |
| gpt-6-luna | Responses | dmx-gpt-6-luna.js |
| gpt-6-sol | Responses | dmx-gpt-6-sol.js |

Luna 已实测同样不支持 Chat Completions 下同时使用思考和工具，因此改用完整 Responses 协议；token 参数由协议层生成 `max_output_tokens`。

两个模型均使用 Responses。脚本使用无服务端存储的完整历史重放：设置 `store=false`，移除 `previous_response_id` 和输入条目的远端 `id`，不重放绑定远端资源的 reasoning 对象。正文、函数调用参数、`call_id` 和工具结果保持不变。当前轮仍启用原有思考设置。该脚本用于 Aurai 的 DMX 完整历史请求路径，不用于只传服务端引用的增量请求。

只针对这次报错的两个模型，不更改供应商默认配置或 5.6 系列模型。配套 JSON 是 `providerDetails.requestAdapters` 的内容，供配置工具使用，不是脚本编辑器内容。

Luna 已使用实际脚本通过两轮真实 Responses 流式请求验证：第一轮携带 reasoning 和 function tools，第二轮重放完整输出与工具结果，两轮均返回 completed。Sol 的同一脚本尚未做独立网络验证。两个模型配置已写入手机数据库；运行中的 App 需重新加载配置。没有安装、停止或重启 App。
