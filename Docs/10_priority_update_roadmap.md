# Priority Update Roadmap

## Purpose
- 将用户确认的一二优先级需求整理为下一轮开发的统一依据。
- 保持与现有文档体系一致：`Docs` 根目录负责项目级说明，`Docs/superpowers/specs` 负责设计规格，`Docs/superpowers/plans` 负责实施计划。
- 只定义下一轮开发的目标、顺序与验收边界，不在本文件中直接改写 PDF 既有规则。

## Current Project Baseline
- 当前项目已经打通标题页、主编辑页、市场、战斗、休整、Boss 结算的单局主循环。
- `RunState` 已管理局内状态、路线推进、市场刷新、掉落、战前快照与休整恢复。
- 主编辑页已经有怪物信息、羁绊面板、帮助按钮、战斗弹窗与拖拽编辑。
- 当前缺口集中在长期留存、策略深度、首次上手、信息可读性，而不是基础主循环是否存在。

## Priority 1

### 0. One-Step Entry Into Battle
- Goal: remove the extra confirmation click between `market -> battle` and `rest -> battle`, so the player enters combat from the main editor flow in one action.
- Why now: this is a core-loop friction issue in the currently playable path and should take precedence over other quality improvements.
- Scope:
  - define the intended one-click transition for both `market -> battle` and `rest -> battle`
  - open battle immediately when the next routed node is `battle` or `boss_battle`
  - preserve existing route advancement, snapshot, and battle result semantics
  - keep non-battle transitions unchanged
- Acceptance:
  - from `market`, one primary-action click should both advance the route and open the battle popup if the next node is `battle`
  - from `rest`, one primary-action click should both advance the route and open the battle popup if the next node is `battle`
  - the change must not introduce duplicate route advancement, duplicate battle preparation, or skipped node effects
- Constraints:
  - solve this in the route/action flow itself, not with UI-only workarounds, fallback flags, or post-processing fixes

### 1. Save / Continue
- 目标：让玩家可以关闭游戏后继续当前冒险，而不是每次都从头开始。
- 原因：这是当前最直接影响留存和反复试玩意愿的缺口。
- 本轮范围：
  - 局内进度持久化
  - 标题页继续游戏入口
  - 首次进入无存档时仅显示开始游戏
  - 存档损坏或版本不兼容时给出明确处理路径
- 本轮不包含：
  - 多存档槽
  - 云存档
  - 回放或历史局记录

### 2. Economy And Build Decision Depth
- 目标：提升“买格子、买食材、刷新商店、保留金币”之间的真实取舍。
- 原因：当前体验更接近被动接收资源，难以形成阵容构筑与特殊对策。
- 本轮范围：
  - 审视起始金币、战斗奖励、市场价格、掉落价值曲线
  - 审视拓展块价格与刷出节奏
  - 审视食材包数量、折扣与稀有度出现节奏
  - 让战士不再过度依赖“先吃到大块高值装备”
- 设计要求：
  - 通过统一数值口径与资源节奏调整解决问题
  - 不引入临时补贴、保底黑箱或局部特判

### 2A. 平衡性重构优先说明
- 目标：把当前平衡调整从零散改数值，改成分阶段重构，避免经济、战斗成长和 build 自由度互相打架。
- 下一轮平衡调整的优先顺序：
  - P0：先修复影响平衡判断的实现错位，再动数值表
  - P1：先收敛市场与经济波动
  - P2：再压平怪物成长波动
  - P3：再调整角色基础数值，重点处理战士过度依赖前期高roll装备的问题
  - P4：最后补 build 自由度和路线系统身份
- P0 范围：
  - 修复当前始终生效、或和实际持有关系脱节的食物效果
  - 修复已经计算但没有真正接入玩法循环的经济类效果
  - 在调数值前，先确认所有关键食物被动都有真实运行时效果
- P1 范围：
  - 重调 `initial_gold`
  - 重调扩容价格，优先看 `1x4`、`2x2`、`2x4`
  - 收窄食物包数量波动，让市场结果更可规划
  - 增加明确的掉落稀有度节奏，避免当前“只按类别掉落”导致前期也能过早跳出高稀有度物品
- P2 范围：
  - 如果普通怪顺序仍然保持随机，就需要降低 `monster_hp_multiplier_curve` 和 `monster_attack_multiplier_curve` 的陡峭程度
  - 如果后续把怪物顺序改成更稳定的阶段式分布，再考虑保留更强的成长曲线
- P3 范围：
  - 先小幅提高战士的基础生存和输出，再看是否还需要通过物品补偿
  - 不要用隐藏追赶、保底奖励或特殊照顾去掩盖前排角色的结构性问题
- P4 范围：
  - 降低“扩容目标角色完全随机”带来的被动应对感
  - 可以考虑允许单次市场里有限度地出现重复食物定义
  - 如果路线里的 `rest` 设计目标是恢复，而不是单纯的过路节点，就需要补齐它的系统身份
- 约束：
  - 不要用保底奖励、怜悯掉落、黑盒补偿之类的方式掩盖结构问题
  - 先修正波动来源和算法结构，再基于修正后的系统去调数值

### 3. One-Time Pre-Battle Formation Adjustment
- 目标：在每场战斗开始前给玩家一次明确的站位调整机会。
- 原因：这是当前补足策略空间、缓解角色吃装备不均的最低成本高收益系统。
- 本轮范围：
  - 战前显示三名角色的出战顺序
  - 允许一次交换或重排
  - 战斗结算读取调整后的承伤/目标顺序
  - 与怪物战中换位效果保持一致的状态模型

### 4. First-Time Tutorial
- 目标：首次游玩时自动引导玩家完成最小可理解流程。
- 原因：现有帮助页已经存在，但仍属于“玩家主动去找”，不能替代首玩引导。
- 本轮范围：
  - 首次进入主编辑页自动弹出
  - 只覆盖核心操作：看商店、放食材、看怪物、开始战斗、休整恢复
  - 教程完成状态持久化
  - 后续仍可通过帮助按钮再次查看

## Priority 2

### 1. Decision-Critical UI Visibility
- 目标：先把影响决策的信息做清楚，而不是先做纯美术润色。
- 重点范围：
  - 商店中的羁绊/类别识别
  - 怪物名称、技能摘要、奖励预期
  - 长文本特殊效果的换行与层级
  - 当前节点、剩余路线、战前风险信息的可扫读性

### 2. Route Map
- 目标：把固定路线从文字提示升级为可视路线图。
- 原因：路线是资源规划的前提，路线图能直接支撑经济决策与风险预期。
- 本轮范围：
  - 已完成节点
  - 当前节点
  - 后续节点类型
  - Boss 前的整体进度感

### 3. Bug Fix Sprint
- 目标：集中处理影响可玩性和可信度的问题。
- 本轮优先处理：
  - 阻断流程的 bug
  - 错误结算或错误数值显示
  - 拖拽/放置/站位相关异常
  - 文本显示与 tooltip 误导

### 4. Lunchbox Visual Polish
- 目标：在不改玩法的前提下，提高饭盒与放置区域的辨识度和美术完成度。
- 说明：这一项排在信息可视性和路线图之后，避免纯表现优化抢占系统时间。

## Deferred After Priority 1 And 2
- 消耗改耐久度
- 局内数值成长
- 图鉴功能
- 新增剧情文案
- 加载动画
- 角色技能
- 局外成长

## Recommended Delivery Order
Top priority: implement one-step battle entry for `market -> battle` and `rest -> battle`.
`经济与 build 决策深度` 这一项内部的平衡调整顺序：先修实现层问题 -> 再收敛市场/包数/掉落波动 -> 再压平怪物成长波动 -> 再调角色基础数值 -> 最后补 build 自由度。
1. 先完成存档骨架与标题页继续游戏入口。
2. 在可持续保存的前提下重做经济曲线。
3. 接入战前站位调整，让数值调整能立刻转化为策略体验。
4. 用首次教程降低新玩家理解成本。
5. 补决策信息 UI 与路线图。
6. 最后做 bug 清扫与局部视觉 polish。

## Exit Criteria
- `market -> battle` and `rest -> battle` should enter battle in one primary-action click without an intermediate idle stop on the editor screen.
- 平衡性调整验收标准：
  - 不应再存在影响平衡判断、但没有真正接入运行时行为的食物或经济效果
  - 市场决策应更多来自规划，而不是来自包数量的大幅波动
  - 前后期战斗强度差异应主要来自设计目标，而不是“怪物顺序随机 + 成长倍率过陡”叠出来的失控波动
  - 战士不应再主要依赖前期高roll拿到强物品，才能显得可用
- 玩家可以关闭后继续当前冒险。
- 玩家在市场与战前有明确可思考的取舍，而不只是被动使用现成资源。
- 首次玩家在不看外部说明的情况下可以完成第一场战斗。
- 重要信息在一个屏幕内可读、可比较、可解释。
