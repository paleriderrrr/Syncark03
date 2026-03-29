# Godot Core Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Godot-native foundation for Syncark03 with resource-driven data, autoload run state, and the initial scene/UI shell.

**Architecture:** Use typed `Resource` assets for static game content, one `Autoload` singleton for run state, and `Control`-based scenes for the title, settings, editor, and battle popup flows. Preserve user-confirmed rules as data first, then add executable systems incrementally.

**Tech Stack:** Godot 4.6 project settings, GDScript, `.tres` resources, `Control` UI scenes, no plugins.

---

### Task 1: Create data resource script types

**Files:**
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Data/character_definition.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Data/food_definition.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Data/monster_definition.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Data/market_config.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Data/stage_flow_config.gd`

- [ ] Step 1: Write the resource class skeletons with typed exported fields.
- [ ] Step 2: Review each field against the confirmed docs and user clarifications.
- [ ] Step 3: Save scripts and make sure names and responsibilities stay narrow.

### Task 2: Create the initial static content assets

**Files:**
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Data/Characters/*.tres`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Data/Foods/*.tres`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Data/Monsters/*.tres`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Data/Configs/market_config.tres`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Data/Configs/stage_flow_config.tres`

- [ ] Step 1: Create character assets for warrior, hunter, and mage from the confirmed stats.
- [ ] Step 2: Create all 54 food assets from the user-provided table, storing passive descriptions faithfully.
- [ ] Step 3: Create monster assets for the six normal monsters and boss, documenting the chosen spice-monster attack values.
- [ ] Step 4: Create market and stage flow config assets from the confirmed docs.

### Task 3: Create the run-state autoload

**Files:**
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/Autoload/run_state.gd`
- Modify: `E:/LargeScaleTestArea/Syncark03/syncark-03/project.godot`

- [ ] Step 1: Add a typed run-state script for current gold, route index, selected character tab, inventory, and per-character bento snapshots.
- [ ] Step 2: Add initialization methods for a fresh run using the confirmed starting values.
- [ ] Step 3: Register the run-state script as an autoload in `project.godot`.

### Task 4: Create the first UI scene shell

**Files:**
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scenes/title_screen.tscn`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scenes/settings_screen.tscn`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scenes/main_editor_screen.tscn`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scenes/battle_popup.tscn`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/UI/title_screen.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/UI/settings_screen.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/UI/main_editor_screen.gd`
- Create: `E:/LargeScaleTestArea/Syncark03/syncark-03/Scripts/UI/battle_popup.gd`

- [ ] Step 1: Build Control-based scenes with the required layout regions and confirmed buttons/labels.
- [ ] Step 2: Connect simple transitions between title, settings, and main editor.
- [ ] Step 3: Mount the battle popup as a large popup owned by the main editor scene.
- [ ] Step 4: Bind the editor shell to the run state for gold, route progress, and selected role tab display.

### Task 5: Verification and logging

**Files:**
- Modify: `E:/LargeScaleTestArea/Syncark03/syncark-03/Docs/07_progress_log.md`

- [ ] Step 1: Run any available static verification or local Godot command if the executable is found.
- [ ] Step 2: Record what was implemented, what was verified, and what remains blocked.
- [ ] Step 3: Keep the progress log append-only and preserve field names.
