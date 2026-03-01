# Phase 1: Local Movement Prototype (No Networking)

## Status: NOT STARTED

## Prerequisites
- Phase 0 complete (test harness working)

## Goal
Make the player feel good offline first: run, jump, air control, friction, gravity. Add jetpack and dive/roll placeholder as simple impulses. No weapons yet.

## Implementation Notes
- Player is `CharacterBody2D`
- Movement is tick-based using `_physics_process(delta)`
- Variables exposed for tuning (exported or in a constants resource)
- Input sampling should be separated from movement simulation
- **Movement model:** The velocity/state calculation (acceleration, friction, gravity, fuel) should be deterministic and shared — given the same input + state, it produces the same velocity. Collision resolution is delegated to Godot's `move_and_slide()`, which depends on the physics scene. This means client prediction replay may resolve collisions slightly differently than the server did — reconciliation (Phase 3) handles this.
- **Facing direction:** Player sprite should flip based on mouse position (left/right of player). This establishes the aiming foundation used in Phase 4. Include `aim_angle` in the input struct even though weapons aren't implemented yet.

## Deliverables

### 1. Player.tscn + PlayerController.gd
Location: `res://scenes/Player.tscn`, `res://scripts/player/PlayerController.gd`

Player node structure:
```
Player (CharacterBody2D)
  ├── CollisionShape2D
  ├── Sprite2D (placeholder)
  └── Camera2D (for local player)
```

PlayerController.gd handles:
- Horizontal movement (left/right) with acceleration
- Jumping with variable height (tap vs hold)
- Air control (reduced acceleration in air)
- Ground friction / air friction
- Gravity
- Jetpack (upward thrust while holding key, consumes fuel)
- Dive/roll placeholder (impulse in movement direction)

### 2. MovementTuning.gd
Location: `res://scripts/player/MovementTuning.gd`

Constants or Resource file with all tunable values:
```gdscript
const MAX_SPEED := 300.0
const GROUND_ACCEL := 1500.0
const AIR_ACCEL := 800.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 980.0
const GROUND_FRICTION := 0.85
const AIR_FRICTION := 0.95
const JETPACK_FORCE := -600.0
const JETPACK_MAX_FUEL := 100.0
const JETPACK_BURN_RATE := 50.0
const JETPACK_RECHARGE_RATE := 25.0
const DIVE_IMPULSE := 500.0
```
These are starting values — tune to feel.

### 3. MovementTestMap.tscn
Location: `res://scenes/MovementTestMap.tscn`

Simple test level with:
- Flat floor
- Several platforms at different heights
- Walls to test collision
- Spawn point for player

### 4. Debug Overlay (F1)
Extend `Debug.gd` or create a debug overlay scene showing:
- Current velocity (x, y)
- Grounded state (true/false)
- Jetpack fuel remaining
- Toggle with F1 key

## Input Mapping
Set up in project.godot input map:
- `move_left` — A / Left Arrow
- `move_right` — D / Right Arrow
- `jump` — Space / W / Up Arrow
- `jetpack` — Shift
- `dive` — Ctrl
- `fire` — Left Mouse Button (placeholder, used in Phase 4)

Mouse position is read via `get_global_mouse_position()` each frame to determine aim angle and facing direction.

## Tests

### test_movement_basic.tscn / test_movement_basic.gd
- Spawn player on flat ground
- Simulate right input for N physics frames
- Assert player x-velocity is within expected range (> 0, < MAX_SPEED)
- Assert player x-position has increased
- Simulate jump input
- Assert player y-velocity is negative (going up)
- Assert player is not grounded after jump

### test_jetpack_fuel.tscn / test_jetpack_fuel.gd
- Spawn player
- Record initial fuel (should be max)
- Hold jetpack input for several frames
- Assert fuel has decreased
- Continue until fuel reaches 0
- Assert jetpack thrust stops (y-velocity not being boosted)
- Release jetpack, wait frames
- Assert fuel recharges (if recharge is implemented)

## Phase Complete Checklist
- [ ] Player.tscn created with correct node structure
- [ ] PlayerController.gd handles all movement mechanics
- [ ] MovementTuning.gd has all constants (no magic numbers in controller)
- [ ] MovementTestMap.tscn playable — can run, jump, jetpack, dive
- [ ] Debug overlay shows velocity, grounded, fuel on F1
- [ ] test_movement_basic — all PASS
- [ ] test_jetpack_fuel — all PASS
- [ ] Code review: movement math isolated? tuning centralized? input sampling separate from sim?
- [ ] Refactor if needed
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Architecture Notes for Future Phases
The velocity/state calculation should be structured so it can be called by:
- Local player (Phase 1)
- Server simulation (Phase 2)
- Client prediction replay (Phase 3)

Ideal signature:
```gdscript
func calculate_velocity(state: Dictionary, input: Dictionary, delta: float) -> Dictionary
```
Where state = {position, velocity, grounded, fuel} and input = {move_dir, jump, jetpack, dive, aim_angle}

**Important distinction:** This function computes the new velocity and fuel state deterministically. Collision resolution (`move_and_slide()`) happens afterward and is scene-dependent. On the server, the post-collision position is authoritative. On the client, prediction uses the local collision result, and reconciliation corrects any drift.

## Files to Create/Modify
```
scenes/Player.tscn
scenes/MovementTestMap.tscn
scripts/player/PlayerController.gd
scripts/player/MovementTuning.gd
tests/test_movement_basic.tscn
tests/test_movement_basic.gd
tests/test_jetpack_fuel.tscn
tests/test_jetpack_fuel.gd
scripts/Debug.gd (update with overlay)
project.godot (input mappings)
```
