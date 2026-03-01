# Tadlos - 2D Multiplayer Shooter (Soldat-inspired)

## Project Overview
A 2D multiplayer shooter inspired by Soldat, built in Godot 4.x with GDScript. Target: 8 players, PC desktop, deathmatch MVP.

## Tech Stack
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Networking:** ENet (`ENetMultiplayerPeer`) using `MultiplayerAPI` RPCs
- **Topology:** Listen server (host runs server + local client), direct connect by IP:port
- **Target:** 8 players, PC desktop first

## Project Structure
```
res://scenes/              # All .tscn scene files
res://scripts/             # General scripts
res://scripts/net/         # Networking scripts
res://scripts/player/      # Player-related scripts
res://scripts/weapons/     # Weapon scripts
res://scripts/projectiles/ # Projectile scripts
res://tests/               # Test scenes and scripts
```

## Phase Tracker
Each phase has a detailed spec in `docs/phases/phase-N.md`. Read the relevant phase doc before starting work.

| Phase | Name | Status |
|-------|------|--------|
| 0 | Repo + project skeleton + test harness | DONE |
| 1 | Local movement prototype (no networking) | DONE |
| 2 | Networking foundation (host/join + replicated players) | DONE |
| 3 | Client-side prediction + reconciliation | DONE |
| 4 | Projectile weapons MVP (server-authoritative) | DONE |
| 5 | Respawn loop + scoring + game rules | DONE |
| 6 | 8-player stability pass + net debug tools | DONE |

**Update this table as phases are completed.** Mark as `IN PROGRESS` when starting, `DONE` when the phase-complete loop passes.

## Phase Completion Protocol (MANDATORY)
Every phase MUST follow this loop before being marked complete:

1. Add/update tests for new behavior
2. Run all tests and confirm PASS
3. Code review checklist:
   - Naming conventions consistent (snake_case for functions/vars, PascalCase for classes/nodes)
   - No duplicated logic
   - Clear ownership (who owns what node/data)
   - RPC safety (validate sender, server-authoritative checks)
4. Refactor if needed
5. Run all tests again and confirm PASS
6. Update the phase status in this file
7. Only then declare phase complete

## Testing Approach
- **Primary:** Test scenes in `res://tests/` that print PASS/FAIL
- **Runner:** `TestRunner.tscn` runs all test scenes and reports results
- **Utility:** `Assert.gd` provides `assert_true`, `assert_eq`, etc.
- **Optional:** GUT plugin for more robust automated testing
- Tests can be run headless for CI-like workflow

## Server Authority Reference
The server is the single source of truth for all gameplay state. Clients only own their input.

| System | Authority | Notes |
|--------|-----------|-------|
| World/map | Server | Collision geometry, spawn points |
| Player position/velocity | Server | Clients predict locally, server reconciles |
| Player aim angle | Client-sent, server-validated | Replicated to other clients for rendering |
| Bullets | Server | Server spawns, simulates, detects hits |
| Damage / HP | Server | Only server calls `take_damage()` |
| Deaths / Respawns | Server | Server decides when/where to respawn |
| Scores | Server | Server increments, broadcasts to clients |
| Game rules (mode, timers) | Server | Clients display only |

## Network Constants (define early, used from Phase 2+)
```
TICK_RATE            = 30        # Server simulation Hz
SNAPSHOT_RATE        = 30        # Snapshots/sec sent to clients (= tick rate for MVP)
MAX_INPUT_RATE       = 30        # Max client input sends/sec (1 per tick)
MAX_PLAYERS          = 8
DEFAULT_PORT         = 7777
INTERPOLATION_DELAY  = 100ms     # Remote player render delay
RECONCILIATION_EPSILON = 2.0px   # Threshold before correction triggers
```
These should live in a shared constants file (e.g., `NetConstants.gd`) so both client and server reference the same values.

## Player Aiming Model
Aiming is mouse-based and must be defined before weapons work:
- **Aim angle:** Derived from player position → mouse world position
- **Facing direction:** Player sprite flips based on whether aim angle points left or right
- **Muzzle origin:** Offset from player center, rotated by aim angle (e.g., shoulder/gun tip)
- **Network replication:** Client sends aim angle with input each tick. Server validates (optional: clamp rate of change). Server broadcasts aim angle to other clients so remote players render correct facing/weapon direction.
- **Phase 1** introduces facing direction (flip sprite based on mouse side). **Phase 4** uses full aim angle + muzzle origin for firing.

## Coding Conventions
- **GDScript style:** Follow Godot's GDScript style guide
- **Naming:** snake_case for functions/variables, PascalCase for classes/nodes
- **No magic numbers:** Use constants or exported variables for tuning values
- **Separation of concerns:** Input sampling separate from simulation logic
- **Network authority:** Server is always authoritative for game state (see authority table above)
- **RPC security:** Always validate sender peer IDs, never trust client-sent state

## Agent Handoff Instructions
If you are an AI agent picking up work on this project:

1. Read this file first
2. Check the Phase Tracker table above to find current progress
3. Read the relevant phase doc at `docs/phases/phase-N.md`
4. Check git log for recent changes and context
5. Follow the phase completion protocol exactly
6. Update this file's phase tracker when done

### Prompt Template for Each Phase
When working on a phase, follow this approach:
1. "Implement Phase X per spec. Keep changes small and modular."
2. "Add or update tests for the new behavior."
3. "Run through the tests logically and list expected PASS criteria."
4. "Perform a code review checklist: duplication, naming, responsibilities, RPC security."
5. "If refactor is needed, do it."
6. "Re-run tests and confirm nothing broke."
7. "Summarize files changed/added and how to run tests."

## MVP Definition
The project is MVP-complete when:
- Host can create a match, others join by IP
- Up to 8 players can move (predictive), shoot projectile bullets, take damage, die, respawn
- Deathmatch scoreboard works
- Test runner passes every time before tagging a build
- Basic debug overlay exists to diagnose net issues

## Debug Tools
- **F1 overlay:** Shows velocity, grounded state, fuel (Phase 1+)
- **Net overlay:** Shows is_host, peer_id, player count (Phase 2+)
- **Lag simulator:** Artificial latency/jitter/packet loss (Phase 6)
- **Performance counters:** Bullets alive, RPC counts, tick time (Phase 6)
- `Debug.gd` helper with toggles for hitbox drawing, ping display, etc.
