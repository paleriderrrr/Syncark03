# Syncark03 Godot Core Foundation Design

**Scope**
Build the first executable Godot foundation for Syncark03 under the confirmed rules: Godot follows the current project setting, no plugins, PC-only, battle presented as a large popup, and gameplay data follows the user-confirmed numeric rewrite model.

## Goals
- Establish a Godot-native project structure that keeps data, gameplay state, and UI responsibilities separate.
- Create a resource-driven data layer for characters, monsters, food, market rules, and stage flow.
- Create the first scene shell for the title page, settings page, main editor page, and the battle popup container.
- Prepare the project for later implementation of bento editing, market transactions, and combat without needing to rewrite the core structure.

## Non-Goals In This Phase
- Full drag-and-drop bento placement.
- Full market buying and reroll behavior.
- Full combat simulation and result settlement.
- Final visual polish, animation, or complete art integration.

## Confirmed Constraints
- Engine mode is Godot and should follow the current project setting in `project.godot`.
- No third-party plugins are allowed.
- PC-only scope for now.
- Battle is presented inside the main editor flow as a large popup.
- The final food value model is the rewritten one from `食物清单_数值改写版.md`.
- The 54 foods provided by the user are the current implementation source.
- UI visual style details that were intentionally left open remain undecided and must not be invented as final art direction.

## Architecture
The project will use a three-layer structure:

1. **Data layer**
   Godot `Resource` classes define static game content: characters, foods, monsters, market rules, stage flow, and adventure presets. Concrete `.tres` assets hold the actual data.

2. **State layer**
   An `Autoload` singleton owns the current run state: gold, stage index, shared inventory, character loadouts, purchased bento expansions, and pending battle context.

3. **Presentation layer**
   Control-based scenes render screens and bind to the state layer via clear methods and signals. The main editor scene is the hub. The battle UI is a large popup scene instantiated inside the main editor.

## File Responsibility Plan
- `res://Scripts/Autoload/run_state.gd`
  Own the current run state, route progression, and high-level scene-facing actions.
- `res://Scripts/Data/*.gd`
  Define typed resource classes for character specs, food definitions, monster definitions, market config, and stage flow config.
- `res://Data/**/*.tres`
  Store concrete content records.
- `res://Scenes/*.tscn`
  One scene per major screen.
- `res://Scripts/UI/**/*.gd`
  View/controller scripts that map state data onto Control nodes.

## Data Design
Food data must be fully configurable. Each food definition will include:
- id
- display_name
- category
- rarity
- gold_value
- shape_cells
- base_stats
- passive_text
- passive_effect_stub
- hybrid_categories

The first phase stores the user-provided passive descriptions as authoritative text and leaves a clear hook field for later executable passive logic. This avoids inventing behavior while still preserving the exact design source.

Monster data will include:
- id
- display_name
- category
- base_hp
- base_attack
- attack_interval
- skill_summary
- target_rule

For the spice monster, the implementation will explicitly choose balanced placeholder-complete values and record them in docs and logs because the user authorized implementation choice.

## UI Structure
The project starts with four scenes:
- `title_screen.tscn`
- `settings_screen.tscn`
- `main_editor_screen.tscn`
- `battle_popup.tscn`

The main editor scene contains:
- Left role tab area
- Center bento editor placeholder
- Bottom shared inventory panel
- Top market strip placeholder
- Right run status column for gold, route progress, and battle entry
- A `PopupPanel`-style large battle container

This keeps the UI faithful to the docs while allowing functionality to be added incrementally.

## Testing Strategy
No Godot executable is currently available on PATH, so runtime verification may be blocked in this environment. The phase will still be implemented test-first where practical by:
- creating deterministic data validation scripts or lightweight scene scripts first,
- wiring verification commands that can be run once the local Godot executable is available,
- and clearly documenting any unrun verification.

## Phase 1 Deliverable
At the end of this phase, the project should have:
- typed data resource classes,
- initial `.tres` content assets,
- an autoload run-state singleton,
- core scenes for title/settings/editor/battle popup,
- UI shells that render confirmed labels and major layout regions,
- and a documented record of remaining gameplay implementation work.

## Remaining Risks
- A few user-supplied shape diagrams need careful normalization into coordinate lists.
- Without a local Godot executable, runtime verification may remain pending.
- Passive food logic is too broad to fully implement in the same first pass without collapsing scene and rules responsibilities together, so phase 1 preserves definitions faithfully and creates the hooks for phase 2 behavior.
