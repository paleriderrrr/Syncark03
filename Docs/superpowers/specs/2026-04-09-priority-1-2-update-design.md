# Syncark03 Priority 1 And 2 Update Design

**Scope**
Define the next development wave after the playable prototype baseline. This wave focuses on four first-priority systems and four second-priority improvements: persistence, economy depth, pre-battle formation control, first-time tutorial, decision-critical UI readability, route-map visualization, bug triage, and lunchbox visual polish.

## Goals
- Convert the current one-session prototype into a replayable build that supports returning players.
- Increase meaningful build decisions before and between battles.
- Reduce first-play confusion without changing the core loop.
- Improve the readability of battle-preparation information before expanding content breadth.

## Non-Goals In This Wave
- Multi-slot save management
- Cloud sync
- Durability or alternative consumption systems
- In-run meta growth layers beyond current food/build decisions
- Encyclopedia, story system, loading animation, character skills, or out-of-run progression

## Confirmed Current State
- The run loop is already connected from title screen to market, battle, rest, and boss resolution.
- `RunState` is the current source of truth for active run data, route state, inventory, board state, market offers, and battle reports.
- Help-guide assets already exist and can be reused for tutorial onboarding.
- Route progress, monster summary, risk text, and tooltip systems already exist in the UI, but mostly as prototype-level information surfaces.
- No disk persistence currently exists for active run state.

## Design Principles
- Preserve the current fixed-route, three-character, food-build identity.
- Improve strategy through explicit systems and clear numbers, not hidden catch-up logic.
- Prefer extending existing `RunState` and scene responsibilities over introducing parallel state holders.
- Prioritize player-understandable decisions before adding more content volume.

## Feature Design

### 1. Persistence And Continue Flow

**Intent**
Allow the player to stop and resume a run without losing progress.

**Recommended Minimal Scope**
- One active-run save file
- Title-screen `Continue` entry when a valid save exists
- Save deletion when a run is fully finished and the player starts a new run, or when the user explicitly overwrites

**State Coverage**
The save payload should cover:
- gold
- route index and market index
- reroll count
- selected character
- shared inventory
- per-character board state
- pending and placed expansions
- battle history needed for route continuity
- first-time tutorial completion flags
- lightweight settings flags needed by the same flow

**Behavior Rules**
- Saving should be event-driven from authoritative run-state mutations, not duplicated ad hoc across UI scripts.
- Loading should rebuild the run from one serialized snapshot rather than replaying partial UI actions.
- Title-screen continue visibility should depend on actual loadable save presence, not a loose boolean flag.

### 2. Economy Rebalance For Decision Depth

**Intent**
Create real tension between buying expansions, buying food packages, rerolling, and preserving gold for later markets.

**Primary Levers**
- initial gold
- normal battle reward curve
- drop-value curve
- expansion price table
- market rarity distribution by market index
- quantity ranges
- discount distribution curve
- reroll cost curve only if necessary after the above levers are exhausted

**Success Criteria**
- The player should routinely face at least one meaningful tradeoff in each market.
- Warrior viability should no longer hinge mainly on receiving the earliest large-value pieces.
- Strategy should come from build shaping and route planning, not from lucky early bulk value alone.

**Restrictions**
- Do not solve shallow economy with opaque free handouts or special-case comeback bonuses.
- Do not patch one role in isolation if the root cause is shared gold pressure or market structure.

### 3. One-Time Pre-Battle Formation Adjustment

**Intent**
Give the player one explicit chance to alter frontline/midline/backline order before each battle begins.

**Functional Rules**
- Formation editing happens during battle preparation, not mid-battle.
- The default order remains warrior -> hunter -> mage unless changed by the player.
- The player may reorder all three characters once before confirming battle.
- Combat target order and any position-sensitive presentation read from the chosen formation.
- Monster effects that swap positions must operate on the same formation state model rather than a separate visual-only order.

**UX Goal**
- The player should understand the consequence of the order change before pressing battle.
- The system should feel like a tactical choice, not an obscure hidden modifier.

### 4. First-Time Tutorial

**Intent**
Turn the existing optional help content into onboarding for first-time players.

**Recommended Structure**
- page 1: what the player is trying to do this run
- page 2: how to buy and place food
- page 3: how to read monster / route / battle entry info
- page 4: how rest restoration and repeated attempts work

**Behavior Rules**
- Auto-open only for first-time entry into the main editor.
- Once completed, remember completion in persistent data.
- The help button should reopen the same guide content at any time.

### 5. Decision-Critical UI Visibility

**Intent**
Improve the information that directly supports purchases, placement, and battle preparation.

**Priority Information Surfaces**
- monster name
- monster skill summary
- route position and next node awareness
- food category / synergy readability in the market
- effective purchase price, quantity, and discount
- long special-effect text wrapping and hierarchy

**Readability Rules**
- Important labels should be scannable in one pass.
- Long text should wrap without truncating key mechanical meaning.
- UI emphasis should follow gameplay importance, not decorative balance.

### 6. Route Map

**Intent**
Replace route text-only awareness with a route visualization that supports planning.

**Minimum Scope**
- all route nodes visible in order
- current node highlighted
- completed nodes visually distinct
- future markets, rests, and boss readable at a glance

### 7. Bug-Fix Policy For This Wave

**Priority Order**
1. progression blockers
2. incorrect battle or economy settlement
3. drag/drop and formation desync
4. misleading UI display bugs
5. cosmetic issues

**Rule**
Bug work in this wave should support the new priority systems first, not become an unbounded generic cleanup branch.

### 8. Lunchbox Visual Polish

**Intent**
Raise visual clarity after the decision-critical information layer is stable.

**Acceptable Scope**
- clearer board ownership
- cleaner expansion/readable occupied-area distinction
- improved lunchbox presentation assets

**Not The Goal**
- full visual overhaul of unrelated screens

## Architecture Impact
- `RunState` remains the persistence and run-authority center.
- Title screen must become state-aware of save presence.
- Main editor must display formation editing, tutorial state, route-map state, and richer information hierarchy.
- Combat must consume formation data from state rather than assuming a fixed hard-coded order.

## Testing Strategy
- Add save/load round-trip tests around serialized run snapshots.
- Add formation-order tests that verify target order changes affect combat results.
- Add UI tests for continue-button visibility, tutorial first-open behavior, and route-map rendering.
- Re-run existing campaign and editor interaction tests after economy and formation changes.

## Main Risks
- Economy changes can create the illusion of more choice while still leaving one dominant purchase path.
- Save-schema changes can silently break older local data if versioning is ignored.
- Formation can become fake depth if UI feedback is weak or if only one order is ever optimal.
- Tutorial can become noise if it explains screens instead of the player’s first real decisions.
