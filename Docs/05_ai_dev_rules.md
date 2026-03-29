# AI Development Rules

## Mission
AI 的目标是严格按照用户最新指令和更新后的策划资料实现，不做自行压缩、不做自行补完、不做自由发挥；当前实现模式已切换为 `Godot`。

## Source Hierarchy
- 第一优先级：用户最新直接指令
- 第二优先级：用户在本地约束文档中的明确补充与确认
- 第三优先级：更新后的 `腾讯极限开发策划案.pdf`
- 第四优先级：更新后的 `食物清单.pdf`
- 第五优先级：[食物清单_数值改写版.md](/D:/2Projects/26.03.28%20Syncark03/食物清单_数值改写版.md)

## Godot Mode
- 当前开发模式为 `Godot`，不再按 Unity 组织实现方案。
- 所有引擎相关设计、目录、场景结构、UI 实现方式都应以 Godot 最佳实践组织。
- 玩法、数值、流程、内容、美术和界面约束仍然来自 PDF 与用户补充，不因引擎迁移而改变。
- Godot 专项实现约束见 [09_godot_development_mode.md](/D:/2Projects/26.03.28%20Syncark03/09_godot_development_mode.md)。

## Question-First Rule
遇到以下任一情况，AI 必须先询问用户，收到明确答复后才能继续：

- 资料之间出现冲突数值
- PDF 或文档中明确写有“待定”
- 缺少完整表格或逐项配置
- 描述不完整，存在多种合理实现方式
- 需要引入任何资料未写明的新规则
- 需要删减、替换、降级、简化任一既有约束
- 需要锁定具体 Godot 版本、插件路线或第三方依赖

## Forbidden Behavior
- 不允许基于 Game Jam 时间压力自行砍功能。
- 不允许把“没有写”理解为“可以自由设计”。
- 不允许用行业常识填补玩法和数值空白。
- 不允许修改数值、概率、流程、角色数、怪物数、食物类别数，除非用户明确批准。
- 不允许擅自把完整 54 种食物改成更少数量。
- 不允许擅自修改 [07_progress_log.md](/D:/2Projects/26.03.28%20Syncark03/07_progress_log.md) 的标题和字段名。

## Required Execution Behavior
- 开发前先读更新后的 PDF 和本约束包。
- 每实现一个模块前，先确认对应约束已足够清晰。
- 若不清晰，立即提问用户，不得继续编码或继续细化实现。
- 若用户给出补充规则，后续文档与实现必须同步更新。

## User-Confirmed Or Current Resolutions
- 初始金币是 `30`
- 危险度评级的计算方式：在没有新指令前，可寻找最合理的算式自由决定
- `54` 种食物的完整定义来源：`食物清单.pdf`
- 香料类怪物未定稿部分：当前先做留空处理，若需要具体数值再问用户
- 特殊稀有度与经济理财流派：当前不作为必须实现项

## Progress Log Rule
AI 每次开始新一轮开发、遇到阻塞、收到新澄清、完成重要里程碑后，都必须更新 [07_progress_log.md](/D:/2Projects/26.03.28%20Syncark03/07_progress_log.md)：
- `Current Status` 反映最新状态
- `Update Log` 只追加，不覆盖
- 每条记录都必须包含：
  - `Completed`
  - `In Progress`
  - `Next`
  - `Blockers`
  - `Files Touched`
  - `Notes`
- 若因资料歧义暂停，`Blockers` 必须明确写出具体待问问题

## Handoff Rule
- 任意 AI 接手时，必须先读：
  - [00_project_brief.md](/D:/2Projects/26.03.28%20Syncark03/00_project_brief.md)
  - [02_scope_and_priorities.md](/D:/2Projects/26.03.28%20Syncark03/02_scope_and_priorities.md)
  - [03_system_specs.md](/D:/2Projects/26.03.28%20Syncark03/03_system_specs.md)
  - [08_ui_design_rules.md](/D:/2Projects/26.03.28%20Syncark03/08_ui_design_rules.md)
  - [09_godot_development_mode.md](/D:/2Projects/26.03.28%20Syncark03/09_godot_development_mode.md)
  - [05_ai_dev_rules.md](/D:/2Projects/26.03.28%20Syncark03/05_ai_dev_rules.md)
  - [07_progress_log.md](/D:/2Projects/26.03.28%20Syncark03/07_progress_log.md)
