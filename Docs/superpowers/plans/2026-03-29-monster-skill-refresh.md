# Monster Skill Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all seven monsters to the latest documented stats and skill behavior, then lock the behavior with automated tests.

**Architecture:** Keep monster base stats in `monster_roster.tres` and implement monster-specific combat behavior centrally in `combat_engine.gd`. Add a dedicated monster automation runner that builds deterministic battle scenarios and asserts each monster's signature mechanics.

**Tech Stack:** Godot 4.6.1, GDScript, `.tres` resources, headless SceneTree test runners

---

### Task 1: Add monster effect automation

**Files:**
- Create: `Scripts/Tests/monster_effect_runner.gd`
- Test: `Scripts/Tests/monster_effect_runner.gd`

- [ ] Step 1: Write a failing monster test runner covering the updated monster mechanics.
- [ ] Step 2: Run the runner in headless mode and confirm it fails against the current implementation.
- [ ] Step 3: Keep the failing assertions as the behavioral contract for the runtime changes.

### Task 2: Update monster data and combat behavior

**Files:**
- Modify: `Data/Monsters/monster_roster.tres`
- Modify: `Scripts/Core/combat_engine.gd`

- [ ] Step 1: Update monster base stats and summaries in `monster_roster.tres`.
- [ ] Step 2: Implement the new monster runtime state and timing logic in `combat_engine.gd`.
- [ ] Step 3: Re-run `monster_effect_runner.gd` until all assertions pass.

### Task 3: Regression verification and progress logs

**Files:**
- Modify: `Docs/07_progress_log.md`
- Modify: `D:/2Projects/26.03.28 Syncark03/07_progress_log.md`

- [ ] Step 1: Run `--quit-after 1`, `campaign_runner.gd`, and `monster_effect_runner.gd`.
- [ ] Step 2: Append a progress-log entry summarizing the monster refresh and verification results.
