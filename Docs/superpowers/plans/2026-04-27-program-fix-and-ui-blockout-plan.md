# Program Fix And UI Blockout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or equivalent repo-local execution workflow to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prioritize gameplay-blocking and decision-misleading program fixes before final art integration, while building UI blockouts for the new interaction and battle-stage requirements so final assets can replace placeholders cleanly when available.

**Architecture:** Keep `RunState` as the single gameplay-state authority. Keep purchase, placement, rotation, inventory paging, food-effect calculation, and lab preview behavior deterministic and testable. UI blockouts may use temporary shapes and colors, but they must preserve final layout contracts instead of adding short-term workaround paths.

**Tech Stack:** Godot 4.6.1, GDScript, `RunState` autoload, resource-driven food and monster data, existing component scenes, headless SceneTree tests where possible.

**Priority Decision:** Program fixes are higher priority than final art. Formal art assets are not available yet, so the next update should implement stable UI blockouts and behavior contracts first, then swap in final textures after delivery.

---

### Task 1: Fix lab crash and effect verification blockers

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\food_effect_lab.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tools\food_effect_lab_state.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\Core\combat_engine.gd`
- Modify/create tests under: `E:\GODOT\MyProject\Syncark03\Scripts\Tests`

- [ ] **Step 1: Reproduce the pudding cup lab crash**

Open or run `Scenes/food_effect_lab.tscn` through the existing test path and identify the exact failing call path for `pudding_cup`.

- [ ] **Step 2: Fix the root cause**

Fix the data, preview, or combat-preview contract that causes the crash. Do not hide the crash behind broad null guards if required state should exist.

- [ ] **Step 3: Add regression coverage**

Add or extend a lab/effect runner so placing or previewing `pudding_cup` no longer exits unexpectedly.

- [ ] **Step 4: Verify related timed effects**

Re-run coverage for foods recently touched by combat-effect fixes so the lab remains a trustworthy validation tool.

### Task 2: Fix inventory paging and hidden third-page item

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\item_strip.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scenes\Components\item_strip.tscn`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\item_icon_card.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scenes\Components\item_icon_card.tscn`
- Modify/create tests under: `E:\GODOT\MyProject\Syncark03\Scripts\Tests`

- [ ] **Step 1: Reproduce the hidden first item on page 3**

Build a deterministic inventory state where `时停伯爵茶` appears as the first entry on the third page and confirm only the right edge is visible.

- [ ] **Step 2: Fix the layout contract**

Correct strip pagination, clipping, card anchoring, or page offset math so every page begins with a fully visible card.

- [ ] **Step 3: Add regression coverage**

Assert page 3 first-card bounds are inside the visible strip area and the icon/card content has non-zero visible width.

### Task 3: Unify market purchase interactions

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\Autoload\run_state.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\item_icon_card.gd`
- Inspect/modify tests: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\editor_dragdrop_runner.gd`

- [ ] **Step 1: Define one purchase contract for all market item types**

Food and lunchbox expansion offers should share the same supported interaction model: click purchase and drag purchase both work through explicit `RunState` APIs.

- [ ] **Step 2: Implement click purchase for food offers**

Clicking a food offer should purchase through the same validation path used by drag purchase and place the result in the correct selected/storage state.

- [ ] **Step 3: Implement drag purchase for lunchbox offers**

Dragging a lunchbox offer should use the same purchase validation path as click purchase, then enter the correct placement path if the drop target is valid.

- [ ] **Step 4: Add behavior coverage**

Verify food click, food drag, lunchbox click, and lunchbox drag all consume gold once, remove or empty the offer consistently, and never duplicate purchased instances.

### Task 4: Stabilize lunchbox rotation and placement

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\Autoload\run_state.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\bento_board_view.gd`
- Inspect/modify tests: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\editor_dragdrop_runner.gd`

- [ ] **Step 1: Inventory current rotation and placement paths**

List the exact paths for inventory-to-board, market-to-board, board pickup, board move, and lunchbox expansion placement.

- [ ] **Step 2: Collapse behavior onto explicit move/rotate APIs**

Ensure rotation and placement state is owned by `RunState` or a clearly bounded selected-item contract, not duplicated in UI nodes.

- [ ] **Step 3: Fix lunchbox expansion rotation**

Verify expansion rotation, valid-cell preview, and final placement use the same occupied-cell calculation.

- [ ] **Step 4: Add focused regressions**

Cover rotated food placement, rotated expansion placement, invalid placement rejection, and moving an already placed item without losing its rotation.

### Task 5: Correct food descriptions and effect consistency

**Files:**
- Inspect/modify food data under: `E:\GODOT\MyProject\Syncark03\Data`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\Core\combat_engine.gd`
- Inspect/modify tooltip builders under: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components`
- Modify tests under: `E:\GODOT\MyProject\Syncark03\Scripts\Tests`

- [ ] **Step 1: Audit `godfather` description against actual rule**

Resolve the mismatch where a 4-cell item references four adjacent cells. Prefer correcting the description if the implementation already matches intended behavior.

- [ ] **Step 2: Audit smoked sausage behavior against description**

Compare data text, tooltip output, and combat implementation for `熏肠`. Decide whether code or description is wrong before changing either.

- [ ] **Step 3: Add effect-description regression cases**

Add targeted assertions for the corrected `godfather` and `熏肠` behavior or text output so future edits do not drift again.

### Task 6: Add adjacency synergy visualization blockout

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\bento_board_view.gd`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Inspect/modify synergy logic under: `E:\GODOT\MyProject\Syncark03\Scripts`
- Modify/create tests under: `E:\GODOT\MyProject\Syncark03\Scripts\Tests`

- [ ] **Step 1: Define visualization states from real adjacency logic**

Use the same adjacency and synergy rules used by gameplay. Do not create a separate visual-only heuristic.

- [ ] **Step 2: Render temporary blockout highlights**

Add clear placeholder states for selected food, checked adjacent cells, valid synergy partners, and missing/invalid partners.

- [ ] **Step 3: Keep the blockout asset-replaceable**

Use named draw/style entry points so final art can replace colors or simple shapes without rewriting the rule calculation.

- [ ] **Step 4: Add validation coverage**

Verify that the highlighted cells match actual adjacent synergy candidates for representative food shapes and rotations.

### Task 7: Build battle-stage popup blockout while waiting for art

**Files:**
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scenes\battle_popup.tscn`
- Inspect/modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\battle_popup.gd`
- Inspect/modify tests: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\battle_playback_runner.gd`
- Inspect/modify tests: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\ui_runner.gd`

- [ ] **Step 1: Convert the popup structure into one stage surface**

Replace the current separated popup/background mental model with one stage blockout containing left curtain, right curtain, actor area, and announcement area.

- [ ] **Step 2: Add the preparation-stage animation contract**

On popup open, the left curtain should reveal the three heroes while the right curtain remains closed. Formation dragging remains available in this state.

- [ ] **Step 3: Add the battle-start animation contract**

After pressing Start Battle, the right curtain opens, the monster is revealed, and automatic battle playback begins only after the reveal state is complete.

- [ ] **Step 4: Add stage-style result announcement**

Use a temporary announcement board for win/lose and major battle messages. The board should be positioned and sized as the future art target.

- [ ] **Step 5: Add regression coverage**

Verify popup open state, start-battle reveal state, actor visibility state, and result-board visibility state.

### Task 8: Final verification and documentation update

**Files:**
- Update: `E:\GODOT\MyProject\Syncark03\Docs\07_progress_log.md`
- Update relevant docs only if implementation changes confirmed behavior

- [ ] **Step 1: Run targeted tests**

Run available runners for lab, food effects, inventory strip, drag/drop, UI, battle playback, and campaign flow.

- [ ] **Step 2: Record any manual-editor checks still needed**

If local headless runtime remains limited, explicitly list the in-editor validation steps.

- [ ] **Step 3: Append progress log**

Record Completed, In Progress, Next, Blockers, Files Touched, and Notes according to `Docs/05_ai_dev_rules.md`.

## Exit Criteria

- `pudding_cup` no longer crashes the food-effect lab.
- Inventory page 3 first item, including `时停伯爵茶`, is fully visible.
- Food and lunchbox market offers share one clear purchase interaction model.
- Lunchbox rotation and placement are deterministic across click, drag, rotate, move, and invalid placement paths.
- `godfather` and `熏肠` descriptions match actual behavior.
- Adjacent synergy visualization reflects real gameplay adjacency rules.
- Battle popup has a working stage blockout: left curtain reveals heroes for formation, right curtain reveals monster on battle start, and result information uses a stage-style announcement board.
- Final art remains optional for this pass; blockout dimensions and named UI surfaces are ready for later texture replacement.
