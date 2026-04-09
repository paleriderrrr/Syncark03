# Priority 1 And 2 Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the user-confirmed first-priority update wave first, then land the second-priority readability and polish work without breaking the current playable loop.

**Architecture:** Keep `RunState` as the single gameplay-state authority. Add one persistence boundary around it, then extend the title screen, main editor, combat engine, and tests in that order. Avoid sidecar state stores or UI-owned truth for save, formation, tutorial, or route-map state.

**Tech Stack:** Godot 4.6.1, GDScript, `RunState` autoload, resource-driven configs (`.tres`), headless SceneTree tests, project docs under `Docs/`.

---

### Task 1: Add persistence coverage and failing tests

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\smoke_runner.gd`
- Create: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\save_load_runner.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Autoload\run_state.gd`

- [ ] **Step 1: Write the failing persistence test**

Cover:
- saving a non-default run snapshot
- loading it into a fresh state instance
- preserving board, inventory, gold, route, and tutorial flags

- [ ] **Step 2: Define serialized snapshot shape**

Add a single authoritative snapshot builder and loader in `RunState`.

- [ ] **Step 3: Add disk-backed save/load/delete APIs**

Implement:
- `save_run() -> bool`
- `load_run() -> bool`
- `has_saved_run() -> bool`
- `delete_saved_run() -> void`

- [ ] **Step 4: Run validation**

Run the new save/load test plus existing campaign flow tests.

### Task 2: Wire title-screen continue flow

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scenes\title_screen.tscn`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\title_screen.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\title_screen_runner.gd`

- [ ] **Step 1: Add continue entry and visibility rules**

Rules:
- show continue only when a valid save exists
- keep start-game flow intact for new runs

- [ ] **Step 2: Connect continue to `RunState.load_run()`**

The title screen should enter the editor on successful load and avoid recreating a fresh run first.

- [ ] **Step 3: Add tests**

Verify:
- no-save state hides continue
- saved-run state shows continue
- continue enters the editor using loaded data

### Task 3: Rebalance the economy in data and verification

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Data\Configs\market_config.tres`
- Modify: `E:\GODOT\MyProject\Syncark03\Data\Configs\stage_flow_config.tres`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\campaign_runner.gd`
- Create: `E:\GODOT\MyProject\Syncark03\Docs\superpowers\specs\2026-04-09-economy-balance-notes.md` if needed during implementation

- [ ] **Step 1: Baseline current market pain points**

Record:
- average affordable offers per market
- expansion purchase pressure
- reroll affordability

- [ ] **Step 2: Adjust the economy through config-first changes**

Prefer touching data curves before touching code.

- [ ] **Step 3: Re-run progression tests**

Verify the run still completes and does not dead-end due to impossible economy.

- [ ] **Step 4: Document the chosen tuning pass**

Record what changed and why.

### Task 4: Add one-time pre-battle formation editing

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Autoload\run_state.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Core\combat_engine.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scenes\main_editor_screen.tscn`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Create: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\formation_runner.gd`

- [ ] **Step 1: Introduce formation state in `RunState`**

Add a clear structure for:
- current formation order
- whether the current battle has consumed its adjustment opportunity

- [ ] **Step 2: Use formation state in combat**

Replace any fixed target-order assumptions that should now read from formation data.

- [ ] **Step 3: Build editor UI for the adjustment**

Provide:
- visible current order
- reorder interaction
- clear battle-start confirmation state

- [ ] **Step 4: Add tests**

Verify:
- default order still matches warrior -> hunter -> mage
- reordered formation changes combat targeting order
- battle reset / next-node flow restores the correct pre-battle behavior

### Task 5: Turn help into first-time tutorial onboarding

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Autoload\run_state.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\ui_runner.gd`

- [ ] **Step 1: Add persistent tutorial-completion state**

Store whether the first-time tutorial has been completed.

- [ ] **Step 2: Auto-open tutorial on first editor entry**

Re-use the existing guide overlay content path where possible.

- [ ] **Step 3: Keep help-button re-entry**

Manual help access must still work after completion.

- [ ] **Step 4: Add tests**

Verify:
- first entry auto-opens
- completion prevents repeat auto-open
- help button still reopens guide

### Task 6: Improve decision-critical UI visibility

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\item_icon_card.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\item_tooltip_builder.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\Components\immediate_item_tooltip_overlay.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\item_tooltip_runner.gd`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\wanted_tooltip_style_runner.gd`

- [ ] **Step 1: Improve hierarchy of monster and market info**

Prioritize name, skill, reward, price, discount, and category readability.

- [ ] **Step 2: Fix long special-effect layout**

Ensure wrapping and panel sizing work for one-line overflow cases.

- [ ] **Step 3: Add tests**

Verify visible text is present and does not clip in known long-text cases.

### Task 7: Add the route map

**Files:**
- Modify: `E:\GODOT\MyProject\Syncark03\Scenes\main_editor_screen.tscn`
- Modify: `E:\GODOT\MyProject\Syncark03\Scripts\UI\main_editor_screen.gd`
- Create: `E:\GODOT\MyProject\Syncark03\Scripts\Tests\route_map_runner.gd`

- [ ] **Step 1: Build route-map presentation state from stage flow**

Use existing stage-flow data instead of duplicating route definitions.

- [ ] **Step 2: Render completed, current, and future nodes distinctly**

The map must be readable at a glance and fit the existing editor layout.

- [ ] **Step 3: Add tests**

Verify node count, current-node highlight, and end-of-route boss visibility.

### Task 8: Run targeted bug-fix and lunchbox polish pass

**Files:**
- Modify only the files directly implicated by findings discovered during Tasks 1-7
- Update: `E:\GODOT\MyProject\Syncark03\Docs\07_progress_log.md`

- [ ] **Step 1: Triage issues by severity**

Order:
- progression blockers
- wrong settlement
- drag/drop or formation desync
- misleading display bugs
- cosmetic polish

- [ ] **Step 2: Fix lunchbox readability issues**

Improve only after the information-critical UI is stable.

- [ ] **Step 3: Run final regression suite**

Run:
- startup / scene load
- save/load
- campaign progression
- editor drag/drop
- formation
- route map
- tooltip layout

- [ ] **Step 4: Update the progress log**

Append the implementation outcomes and touched files under `Docs/07_progress_log.md`.
