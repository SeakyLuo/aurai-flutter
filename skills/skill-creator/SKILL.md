---
name: skill-creator
description: 创建或优化 Aurai 可复用技能，整理使用说明、真实工具依赖和必要的 Android 执行脚本。
---

# 技能创建

仅在用户要求创建或修改技能时保存。先用 searchSkills/listSkills 查找已有技能；更新前 readSkill，保留用户未要求修改的内容，提交其最新 revision。

名称简短易懂；简介说明实际用途和触发场景。说明只保留影响决策的业务规则、输入输出、工具用法和约束，不重复通用常识，不把单次任务的个人数据、凭据或临时结果固化为规则。

优先创建说明型技能，script 为空。通过当前工具 schema 核对工具名称和能力；不使用 Codex 路径、工具命名或假设存在 Python/Node。确实需要重复的确定性处理时才提供 executeAndroidScript 兼容脚本：先 inspectAndroidApi 核对 Java/Android API，说明 inputJson 的全部字段、数据访问和副作用，使用 input 对象读取参数。运行环境没有 Node、浏览器、root 或持久计时器。

createSkill/updateSkill 提供完整内容、可见范围、依赖和图标。依赖必须从已有技能取得，说明何时读取、如何使用；没有依赖填空列表。不要为了创建技能自动安装软件或扩大授权范围。安装与共享内容是独立状态，更新他人公共技能遵循工具审批。

保存不代表运行成功。说明型技能核对工具与操作路径；脚本通过 runSkill 按已有授权验证真实输出，未经执行不得宣称已验证。失败保留原始错误，不原样自动重试产生副作用的操作。
