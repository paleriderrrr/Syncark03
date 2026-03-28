# Editor Redesign And Dragdrop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the main editor page so it matches the approved Godot layout with top market bar, left role tabs, center colored bento board, draggable expansions and food items, and right-side monster/synergy information.

**Architecture:** Keep `RunState` as the single gameplay state authority, but extend it with grouped market/inventory views and explicit drag-safe move APIs. Split the editor UI into focused components for icon-strip rendering, board rendering, and side-panel info so the scene layout stays maintainable while drag/drop and stacking logic remain deterministic.

**Tech Stack:** Godot 4.6.1, GDScript, existing autoload `RunState`, resource-driven data (`.tres`), headless SceneTree tests.

---

### Task 1: Add failing tests for the redesigned editor surface

**Files:**
- Modify: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\Tests\ui_runner.gd`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\Tests\editor_dragdrop_runner.gd`

- [ ] **Step 1: Write the failing editor-layout assertions**

Add assertions in `Scripts/Tests/ui_runner.gd` for:
- top market strip node existing
- left panel only exposing role tabs instead of preview boards
- right panel exposing next-monster panel and synergy panel

- [ ] **Step 2: Run the UI test to verify it fails**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/ui_runner.gd
```

Expected: `UI_TEST_FAIL`

- [ ] **Step 3: Write the failing drag/drop behavior test**

Create `Scripts/Tests/editor_dragdrop_runner.gd` to verify:
- market entries are grouped by definition id with quantity
- inventory entries are grouped by definition id with quantity
- dragging one market item only adds one inventory instance
- moving a placed food to another valid board cell preserves one placed item
- moving an expansion to another valid board anchor updates active cells

- [ ] **Step 4: Run the drag/drop test to verify it fails**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/editor_dragdrop_runner.gd
```

Expected: `EDITOR_DRAGDROP_TEST_FAIL`

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Tests/ui_runner.gd Scripts/Tests/editor_dragdrop_runner.gd
git commit -m "test: cover editor redesign interactions"
```

### Task 2: Extend RunState for grouped item strips and move operations

**Files:**
- Modify: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\Autoload\run_state.gd`

- [ ] **Step 1: Add the failing test expectations from Task 1**

Use the failing tests as the interface contract. No production edits before both tests fail for the intended reasons.

- [ ] **Step 2: Implement grouped strip queries**

Add `RunState` methods that return icon-strip friendly grouped entries:
- `get_grouped_market_entries()`
- `get_grouped_inventory_entries()`
- `get_synergy_summary(character_id: StringName)`
- `get_next_monster_summary()`

Each grouped item entry should include:
- stable item key
- display name
- count
- icon path or texture-ready hint
- source ids needed to consume only one instance

- [ ] **Step 3: Implement explicit move APIs**

Add deterministic methods for editor drag/drop:
- `move_placed_food(from_cell: Vector2i, to_anchor: Vector2i) -> bool`
- `move_pending_expansion(instance_id: StringName, to_anchor: Vector2i) -> bool`
- `pick_market_offer_instance(group_key: StringName) -> Dictionary`
- `pick_inventory_instance(group_key: StringName) -> Dictionary`

- [ ] **Step 4: Run the two headless tests**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/editor_dragdrop_runner.gd
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/campaign_runner.gd
```

Expected: both pass

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Autoload/run_state.gd Scripts/Tests/editor_dragdrop_runner.gd Scripts/Tests/campaign_runner.gd
git commit -m "feat: add stacked editor state queries and move APIs"
```

### Task 3: Build reusable icon-strip and side-panel components

**Files:**
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\UI\Components\item_strip.gd`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scenes\Components\item_strip.tscn`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\UI\Components\item_icon_card.gd`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scenes\Components\item_icon_card.tscn`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\UI\Components\synergy_panel.gd`
- Create: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scenes\Components\synergy_panel.tscn`

- [ ] **Step 1: Create the minimal icon-strip component**

Implement a horizontally scrolling strip that:
- renders icon cards from grouped entries
- emits one signal for selecting a group
- emits one signal for starting a drag for a single instance

- [ ] **Step 2: Create the icon-card component**

Implement a card with:
- food icon texture
- quantity badge
- price badge for market usage when provided
- selected visual state

- [ ] **Step 3: Create the synergy panel**

Implement a compact panel that lists:
- active category counts
- triggered synergy descriptions
- selected role context

- [ ] **Step 4: Run the UI test**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/ui_runner.gd
```

Expected: `UI_TEST_PASS`

- [ ] **Step 5: Commit**

```powershell
git add Scenes/Components/item_strip.tscn Scenes/Components/item_icon_card.tscn Scenes/Components/synergy_panel.tscn Scripts/UI/Components/item_strip.gd Scripts/UI/Components/item_icon_card.gd Scripts/UI/Components/synergy_panel.gd Scripts/Tests/ui_runner.gd
git commit -m "feat: add editor strip and synergy UI components"
```

### Task 4: Rebuild the board component for colored zones and drag/drop

**Files:**
- Modify: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\UI\Components\bento_board_view.gd`

- [ ] **Step 1: Add board-focused failing expectations**

Use the drag/drop test from Task 1 as the contract for:
- zone colors
- placed-food pickup/move
- expansion pickup/move

- [ ] **Step 2: Rework the board rendering model**

Update `BentoBoardView` to render:
- base active cells with one color
- expansion cells with another color
- blocked cells with dark color
- placed foods with food icons
- drag-preview occupancy cells

- [ ] **Step 3: Add board drag/drop signals**

Expose signals for:
- `food_drag_started(instance_id, from_cell)`
- `expansion_drag_started(instance_id)`
- `board_drop_requested(anchor_cell)`

- [ ] **Step 4: Run drag/drop and UI tests**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/editor_dragdrop_runner.gd
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/ui_runner.gd
```

Expected: both pass

- [ ] **Step 5: Commit**

```powershell
git add Scripts/UI/Components/bento_board_view.gd Scripts/Tests/editor_dragdrop_runner.gd Scripts/Tests/ui_runner.gd
git commit -m "feat: add colored board rendering and board drag signals"
```

### Task 5: Rebuild the main editor scene and wire Art assets

**Files:**
- Modify: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scenes\main_editor_screen.tscn`
- Modify: `E:\LargeScaleTestArea\Syncark03\syncark-03\Scripts\UI\main_editor_screen.gd`

- [ ] **Step 1: Rebuild the scene tree layout**

Update the scene so it contains:
- top market strip
- left role-tab column only
- center board workspace
- bottom inventory strip
- right next-monster panel
- right synergy panel

- [ ] **Step 2: Wire drag/drop flows**

Handle:
- drag one market instance to buy and place
- drag one inventory instance to place
- drag placed food to move
- drag expansion to move

- [ ] **Step 3: Deploy Art assets**

Use textures from:
- `res://Art/UI/`
- `res://Art/Food/`

Create a deterministic mapping layer so existing available icons are used for deployment tests and unmapped food ids stay on a single neutral placeholder path.

- [ ] **Step 4: Run full validation**

Run:
```powershell
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --quit-after 1
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/ui_runner.gd
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/editor_dragdrop_runner.gd
& 'E:\applications\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' --headless --path 'E:\LargeScaleTestArea\Syncark03\syncark-03' --script res://Scripts/Tests/campaign_runner.gd
```

Expected: all pass

- [ ] **Step 5: Update both progress logs and commit**

Update:
- `E:\LargeScaleTestArea\Syncark03\syncark-03\Docs\07_progress_log.md`
- `D:\2Projects\26.03.28 Syncark03\07_progress_log.md`

Then run:
```powershell
git add Scenes/main_editor_screen.tscn Scripts/UI/main_editor_screen.gd Docs/07_progress_log.md "D:\2Projects\26.03.28 Syncark03\07_progress_log.md"
git commit -m "feat: redesign editor with dragdrop strips and side panels"
```
