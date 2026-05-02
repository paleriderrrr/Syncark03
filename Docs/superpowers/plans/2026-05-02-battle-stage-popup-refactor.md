# 战斗舞台弹窗重构计划

## 目标

将当前战斗弹窗中“弹窗框”和“内部战斗背景”分离的表现，重构为一个完整的纸片剧场舞台。进入战斗时，舞台弹出并先展示我方部署区域；玩家调整三名角色出战顺序后，点击舞台道具式开始按钮，右侧幕布拉开、怪物登场并开始自动战斗；战斗结束后，通过报幕牌、落幕、聚光灯或横幅等舞台演出方式展示胜负结果。

本次重构只改变战斗弹窗的舞台呈现、节点结构和演出状态，不改变 `CombatEngine` 的战斗规则、结算算法和奖励逻辑。

## 设计原则

- 整个 `BattlePopup` 就是一张完整舞台画面，不再表现为“系统弹窗 + 内部战斗背景”。
- 左侧是我方区域，右侧是敌方区域。
- 按钮、提示、站位、结果信息尽量作为舞台道具呈现。
- 幕布状态必须由真实美术节点表达，不使用纯色遮挡块伪装最终效果。
- 拖拽换位、自动回放、战斗结算保持现有数据链路，避免视觉重构影响战斗规则。
- 不引入临时补丁、启发式遮挡或与素材不匹配的后处理方案。

## 现有基础

主要相关文件：

- `Scenes/battle_popup.tscn`
- `Scripts/UI/battle_popup.gd`
- `Scripts/Tests/battle_playback_runner.gd`
- `Scripts/Tests/ui_runner.gd`
- `Scripts/Tests/campaign_runner.gd`

现有 `BattlePopup` 已经具备以下基础能力：

- 战前准备与开始战斗分离。
- 支持三名角色拖拽换位。
- `CombatEngine.simulate(run_state, _current_party_order())` 已支持按当前队伍顺序模拟。
- 已有阶段常量：
  - `preparation`
  - `monster_reveal`
  - `battle`
  - `result`
- 已有战斗事件回放、飘字、攻击动画、胜负音效、BGM 切换。

当前主要问题：

- `BattlePopup` 尺寸为 `1540x760`，与新素材 `1920x1080` 的 16:9 舞台比例不一致。
- 场景中仍存在旧结构：`WindowArt -> ArenaPanel -> StageArt/StageOverlay`，视觉上像弹窗内嵌战斗背景。
- 幕布状态目前由 `ColorRect` 占位块模拟，不能作为最终美术表现。
- 提示、开始按钮、关闭按钮、结果展示仍偏普通 UI，而不是舞台道具。

## 新素材映射

目录：`Art/NewBattleBackground`

| 素材 | 尺寸 | 用途 |
| --- | --- | --- |
| `battle_stage_popup_bg.png` | `1920x1080` | 舞台底层背景 |
| `battle_stage_overlay.png` | `1920x1080` | 中后景纸片景片，放在角色后方 |
| `battle_curtain_left_panel.png` | `1920x1080` | 左侧幕布关闭/开幕动画 |
| `battle_curtain_right_panel.png` | `1920x1080` | 右侧幕布关闭/开幕动画 |
| `舞台最上层.png` | `1920x1080` | 最前景木制舞台框、顶部红幕和边缘遮挡 |
| `battle_start_normal.png` | `379x299` | 开始战斗木牌按钮默认态 |
| `battle_start_hover.png` | `379x299` | 开始战斗木牌按钮悬停态 |
| `battle_close_normal.png` | `379x299` | 关闭木牌按钮默认态 |
| `battle_close_hover.png` | `379x299` | 关闭木牌按钮悬停态 |

## 目标节点结构

保留 `BattlePopup` 作为透明模态容器，内部改为单一 16:9 舞台根节点。

```text
BattlePopup
  StageRoot
    StageBackground
    BackdropOverlay
    ActorLayer
      HeroSlot1
      HeroSlot2
      HeroSlot3
      MonsterActor
    EffectLayer
      BattleFloatLayer
      SkillCueLayer
    CurtainLayer
      LeftCurtain
      RightCurtain
    PropLayer
      PromptBoard
      StartBattleButton
      CloseBattleButton
      ResultBoard
    FrontStageFrame
```

层级规则：

- `StageBackground` 使用 `battle_stage_popup_bg.png`。
- `BackdropOverlay` 使用 `battle_stage_overlay.png`，位于角色后方。
- `ActorLayer` 承载三名角色和怪物。
- `EffectLayer` 承载伤害飘字、治疗飘字、技能提示。
- `CurtainLayer` 承载左右幕布。
- `PropLayer` 承载提示牌、按钮、结果牌。
- `FrontStageFrame` 使用 `舞台最上层.png`，压在最前景，保证木制舞台框和顶部幕布能遮住越界内容。

## 舞台尺寸与布局

建议将弹窗基准尺寸改为 16:9：

- 优先方案：`1600x900`
- 如主界面空间不足，可退到：`1536x864`

布局基准以预览图为准，按 16:9 舞台内的相对位置落点，而不是按 `1540x760` 旧弹窗手调。

按预览图落位：

- 左侧开景区：舞台左半边保留可见背景与角色位，约 `x = 0.12 - 0.48`
- 右侧闭幕区：舞台右半边由红幕主导，约 `x = 0.50 - 0.92`
- 地面基准线：约 `y = 0.64 - 0.72`
- 中央吊牌：正中悬挂，约 `x = 0.50, y = 0.30`
- 开始木牌：右下角贴边，约 `x = 0.86, y = 0.72`
- 关闭木牌：右上角压边，约 `x = 0.88, y = 0.07`
- 胜负报幕牌：中央偏上，约 `x = 0.50, y = 0.33`

推荐站位关系：

- 我方角色位从左到右排在左侧开景区内，建议 `x = 0.18 / 0.31 / 0.44`
- 敌方怪物位在右侧闭幕区前方，建议 `x = 0.70`
- 角色脚下站位标记紧贴地面，不悬在胸口或头顶
- 提示牌与结果牌都使用悬挂式舞台道具，不使用普通居中弹窗文字

## 阶段一：战前部署

视觉状态：

- 舞台已经弹出。
- 左侧开景，三名角色可见。
- 右侧红幕保持闭合，怪物不可见。
- 中央吊牌显示“调整出战顺序”。
- 每名角色脚下显示清晰的 `1 / 2 / 3` 站位木牌。
- 右下角显示开始木牌按钮，右上角保留关闭木牌。

交互规则：

- 允许拖拽我方角色调整顺序。
- 拖拽换位后，脚下站位编号和 `_current_party_order()` 必须同步更新。
- 怪物数据可以预加载，但节点保持不可见。
- 关闭按钮可用。
- 战斗报告不得提前提交到 `RunState.battle_reports`。

脚本对应：

- `open_battle()` 进入 `STAGE_PHASE_PREPARATION`。
- `_prepare_pre_battle_preview()` 只刷新我方预览和隐藏怪物，不启动模拟。
- `_set_stage_phase(preparation)` 设置：
  - `LeftCurtain` 拉开到左侧，露出左半舞台。
  - `RightCurtain` 覆盖右半舞台。
  - `MonsterActor.visible = false`。
  - `PromptBoard.visible = true`，位置固定在舞台中央上方。
  - `StartBattleButton.visible = true`，位置固定在右下角。
  - `CloseBattleButton.visible = true`，位置固定在右上角。
  - `ResultBoard.visible = false`。

## 阶段二：右幕布拉开与怪物登场

触发：

- 玩家点击开始木牌按钮。

视觉状态：

- 开始木牌按钮禁用并淡出。
- 中央吊牌收起或淡出。
- 右幕布执行横向拉开动画。
- 怪物在幕布打开后出现，可加入轻微缩放或落位动画。

交互规则：

- 进入该阶段后禁止拖拽换位。
- 关闭按钮暂时禁用，避免战斗回放中断。
- 右幕布拉开完成后再进入正式战斗回放。

脚本对应：

- `_on_start_battle_pressed()`：
  - `_is_preparing = false`
  - `_is_playing = true`
  - 禁用开始与关闭按钮。
  - 播放 `UiSfxPlayer.play_battle_start()`。
  - 播放战斗 BGM。
  - `await _play_battle_start_reveal()`。
  - 调用 `CombatEngine.simulate(run_state, _current_party_order())`。

- `_play_battle_start_reveal()` 改造：
  - 设置阶段为 `STAGE_PHASE_MONSTER_REVEAL`。
  - 对 `RightCurtain.position` 或 `modulate` 做 tween。
  - 动画完成后显示 `MonsterActor`。
  - 设置阶段为 `STAGE_PHASE_BATTLE`。

## 阶段三：自动战斗

视觉状态：

- 左右双方都在舞台内可见。
- 飘字、技能提示、攻击动作在舞台区域内表现。
- 事件播报改为舞台小报幕牌，不再依赖普通系统面板。

交互规则：

- 玩家不可调整站位。
- 战斗回放根据报告 log 顺序播放。
- 战斗结果仍在回放结束后才提交。

脚本对应：

- `_prepare_playback()` 设置：
  - 标题类普通 UI 隐藏或弱化。
  - `BattleLog` 默认仍可作为调试面板，但生产表现应使用 `PromptBoard` 或 `EventBoard`。
  - `_set_stage_phase(STAGE_PHASE_BATTLE)`。

- `_process_battle_event(line)` 保持现有事件解析，不改战斗算法。

- `_spawn_float_text()` 需要确保飘字父节点在 `EffectLayer`，并受舞台范围约束。

## 阶段四：战斗结束与报幕

视觉状态：

- 中央出现报幕牌展示胜利或失败。
- 可配合以下一种或多种舞台演出：
  - 报幕牌落下。
  - 木牌翻转。
  - 横幅落下。
  - 聚光灯变亮或聚焦中央。
  - 失败时右侧/全场暗下。
  - 胜利时角色保持亮色，怪物灰暗或倒下。

交互规则：

- 结果展示后恢复关闭按钮。
- `RunState.apply_battle_report(report)` 仍只在回放完成后调用。
- 关闭弹窗后释放 `BattleModalBlocker`。

脚本对应：

- `_render_final_report(report)`：
  - 播放胜负音效。
  - `_apply_final_display_state(report)`。
  - `_set_stage_phase(STAGE_PHASE_RESULT)`。
  - `await _play_result_banner(result)`。

- `_set_stage_phase(result)` 设置：
  - 左右幕布不重新遮挡主要角色，或根据最终演出选择半落幕。
  - `ResultBoard.visible = true`。
- `PromptBoard.visible = false`。
- `MonsterActor.visible = true`。
- `ResultBoard` 保持中央悬挂式报幕位置，不回落到普通面板布局。

## 具体实施步骤

1. 调整 `BattlePopup` 尺寸
   - 将 `POPUP_SIZE` 改为 16:9。
   - 确认 `popup_centered(POPUP_SIZE)` 不超出 `1920x1080` 主视口。

2. 重建 `battle_popup.tscn` 舞台层级
   - 删除旧 `WindowArt` 的弹窗框表现。
   - 删除或停用旧 `ArenaPanel` 的系统面板表现。
   - 新建 `StageRoot` 和分层节点。
   - 替换新素材纹理。

3. 替换幕布实现
   - 删除 `_left_curtain_blockout`、`_right_curtain_blockout` 等最终视觉占位块。
   - 新增 `@onready var left_curtain: TextureRect`。
   - 新增 `@onready var right_curtain: TextureRect`。
   - 用真实幕布节点实现开合状态。

4. 改造阶段状态机
   - `_set_stage_phase()` 只驱动真实舞台节点。
   - 阶段之间只做明确动画和显隐，不使用额外遮挡补丁。

5. 改造开始按钮与关闭按钮
   - 使用 `battle_start_normal/hover.png`。
   - 使用 `battle_close_normal/hover.png`。
   - 按钮可以继续用 Godot `Button`，但主题设为透明，仅使用贴图状态。

6. 改造站位标记
   - 把现有 `TargetBadge` 从角色上方/侧边改到脚下。
   - 视觉上做成木牌或舞台地标。
   - 拖拽换位后调用 `_refresh_target_badges()` 更新编号。

7. 改造报幕牌
   - 保留现有胜负纹理作为第一版内容。
   - 新建 `ResultBoard` 节点承载胜负图或文字。
   - `_play_result_banner()` 改为驱动 `ResultBoard` 的落下/翻转动画。

8. 调整飘字和事件提示
   - 飘字放入 `EffectLayer`。
   - 技能提示显示在舞台小报幕牌上。
   - 默认隐藏 `TimelinePanel`，仅作为调试开关保留。

9. 更新测试
   - `battle_playback_runner.gd` 更新节点路径。
   - 验证战前右幕布关闭、怪物隐藏、开始按钮可见。
   - 验证点击开始后进入 `monster_reveal` 或 `battle`。
   - 验证回放结束后结果牌显示，报告才提交。
   - 保留 `ui_runner.gd` 对开始按钮存在性的断言。

10. 运行验证
    - Godot headless 启动。
    - `Scripts/Tests/battle_playback_runner.gd`
    - `Scripts/Tests/ui_runner.gd`
    - `Scripts/Tests/campaign_runner.gd`

## 验收标准

- 战斗弹窗第一眼是完整舞台，而不是系统弹窗套战斗背景。
- 战前左侧三名角色可见，右侧怪物不可见。
- 右侧幕布关闭状态明确。
- 三个站位编号清晰，拖拽后编号和实际出战顺序一致。
- 点击开始后右侧幕布拉开，怪物登场，然后才开始自动战斗回放。
- 战斗飘字和技能提示均在舞台区域内呈现。
- 胜利或失败后，中央出现舞台报幕牌。
- 结果提交时机不变：战斗回放完成后才写入 `RunState.battle_reports`。
- 关闭战斗弹窗后，主界面遮罩正确释放。
- 相关自动测试通过。

## 风险与注意事项

- 新素材是 `1920x1080`，旧弹窗是 `1540x760`，必须先统一比例，否则舞台会被压扁。
- `舞台最上层.png` 需要放在最前景，否则角色、飘字或幕布可能穿出木制舞台框。
- 幕布 tween 不应改变战斗开始顺序：怪物揭幕后才能进入回放。
- 拖拽换位逻辑已有实现，应复用而不是重写。
- 不要用额外 `ColorRect` 长期遮挡来修补素材边缘；如素材层级不对，应调整节点层级、锚点和裁剪区域。
- 不要改 `CombatEngine` 来配合 UI 表现；UI 只消费战斗报告。

## 建议里程碑

### M1：素材落位

- 完成 16:9 舞台根节点。
- 新背景、景片、前景舞台框显示正确。
- 开始/关闭按钮替换为木牌资源。

### M2：幕布流程

- 战前左开右闭。
- 点击开始后右幕布拉开。
- 怪物按流程登场。

### M3：部署交互

- 三名角色在左侧站位合理。
- 脚下 `1 / 2 / 3` 站位标记清晰。
- 拖拽换位后顺序正确进入模拟。

### M4：战斗回放

- 飘字、技能提示、攻击动画适配新舞台区域。
- 调试用时间线默认隐藏，舞台报幕替代普通面板提示。

### M5：结束演出与验证

- 胜负报幕牌完成。
- 关闭流程正常。
- 自动测试通过。
