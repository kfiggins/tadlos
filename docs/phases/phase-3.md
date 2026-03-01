# Phase 3: Client-Side Prediction + Reconciliation for Movement

## Status: DONE

## Prerequisites
- Phase 2 complete (networking host/join works, players replicated)

## Goal
Movement feels responsive online: local client predicts instantly; server corrects; client reconciles smoothly. Other players interpolate.

## Implementation Notes
- Client sends input with a **sequence number** and **tick**
- Server runs fixed-tick simulation (30 Hz MVP)
- Server sends authoritative state with last processed input sequence
- Client keeps an **input buffer**, rewinds to server state, reapplies pending inputs
- Remote players use **interpolation** with a small buffer (100-150ms)

## Key Concepts

### Client-Side Prediction
1. Client samples input and immediately applies it locally (feels instant)
2. Client sends input + sequence number to server
3. Client stores input in a buffer keyed by sequence number

### Server Reconciliation
1. Server processes inputs in order, simulates movement
2. Server sends back authoritative state + last processed sequence number
3. Client receives server state:
   - Discard all inputs with seq <= server's last_processed_seq
   - Compare server position with local predicted position at that seq
   - If difference > epsilon: snap to server state, replay remaining buffered inputs

### Remote Player Interpolation
1. Client receives position snapshots for other players
2. Buffer snapshots (target ~100-150ms behind)
3. Interpolate between two buffered snapshots for smooth rendering
4. Extrapolate briefly if buffer runs dry

## Deliverables

### 1. ClientPrediction.gd
Location: `res://scripts/net/ClientPrediction.gd`

```gdscript
# Input buffer: Array of {seq: int, input: Dictionary, predicted_state: Dictionary}
var input_buffer: Array = []
var current_seq: int = 0

func record_input(input: Dictionary, predicted_state: Dictionary) -> int:
    # Store input + predicted state, return seq number

func on_server_state(server_state: Dictionary, last_seq: int) -> Dictionary:
    # Discard old inputs
    # Compare server state vs predicted state at last_seq
    # If mismatch: return corrected state after replaying pending inputs
    # If match: return null (no correction needed)
```

### 2. StateSnapshot.gd
Location: `res://scripts/net/StateSnapshot.gd`

Data structure for network state:
```gdscript
class_name StateSnapshot

var peer_id: int
var tick: int
var last_input_seq: int
var position: Vector2
var velocity: Vector2
var grounded: bool
var fuel: float
```

### 3. RemoteInterpolation.gd
Location: `res://scripts/net/RemoteInterpolation.gd`

For rendering remote players smoothly:
```gdscript
var snapshot_buffer: Array = []  # Ring buffer of StateSnapshots
var interpolation_delay: float = 0.1  # 100ms behind

func add_snapshot(snapshot: StateSnapshot) -> void
func get_interpolated_state(current_time: float) -> Dictionary
```

### 4. Update NetworkedPlayer.gd
- Local player: uses ClientPrediction
- Server: runs simulation, sends StateSnapshots
- Remote player on client: uses RemoteInterpolation

### 5. Tick System
- Server maintains authoritative tick counter
- Fixed tick rate: 30 Hz (can tune later)
- All state snapshots include tick number
- Clients sync approximate tick with server

## Reconciliation Algorithm (Detailed)

```
On receive server_state(position, velocity, last_seq):
    # Find our predicted state at last_seq
    predicted = input_buffer.find(seq == last_seq)

    if distance(predicted.position, server_state.position) > RECONCILIATION_EPSILON:
        # Mismatch! Reconcile.
        current_state = server_state  # Trust server

        # Replay all inputs after last_seq
        for input in input_buffer where input.seq > last_seq:
            current_state = calculate_velocity(current_state, input.input, tick_delta)
            apply_move_and_slide(current_state)  # Collision resolution on client scene

        # Apply corrected state
        apply_state(current_state)

    # Prune old inputs
    input_buffer.remove_where(seq <= last_seq)
```

### Collision Resolution Caveat
The velocity calculation (`calculate_velocity()`) is deterministic and shared. But `move_and_slide()` resolves collisions against the local physics scene, which may differ slightly between client and server (e.g., different interpolation states of other players). This means replayed inputs may produce slightly different positions than the original prediction. This is normal — reconciliation handles it by always trusting the server position as the starting point and replaying forward from there.

## Tests

### test_prediction_reconcile.tscn / test_prediction_reconcile.gd
- Create a ClientPrediction instance
- Feed it a series of inputs (move right for 10 ticks)
- Let it predict positions locally
- Simulate a "server response" that matches predicted position
  - Assert: no correction applied
- Simulate a "server response" with position offset (simulating latency mismatch)
  - Assert: client position converges to server position within epsilon after reconciliation
  - Assert: pending inputs are replayed correctly
- Simulate with artificial delay queue (add N frames of latency)
  - Assert: prediction still works, reconciliation converges

### test_remote_interpolation.tscn / test_remote_interpolation.gd
- Create RemoteInterpolation instance
- Feed snapshots at uneven intervals (simulating jitter)
- Query interpolated position at various times
- Assert: rendered position is smooth (no teleporting)
- Assert: position stays within bounds of received snapshots
- Assert: handles missing/late snapshots gracefully

## Phase Complete Checklist
- [ ] ClientPrediction.gd implements input buffering and reconciliation
- [ ] StateSnapshot.gd defines network state structure
- [ ] RemoteInterpolation.gd smooths remote player rendering
- [ ] Local player movement feels instant (no input lag)
- [ ] Server corrections are smooth (no visible snapping in normal conditions)
- [ ] Remote players move smoothly (interpolated)
- [ ] test_prediction_reconcile — all PASS
- [ ] test_remote_interpolation — all PASS
- [ ] Code review: prediction isolated from presentation? No duplicated sim logic?
- [ ] Refactor: extract shared `simulate_movement_step(input)` so server/client use same function
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Architecture Notes
- The velocity calculation function MUST be shared between client prediction and server simulation — single source of truth
- Collision resolution (`move_and_slide()`) is scene-dependent and runs separately on client and server. This is fine — reconciliation corrects any drift.
- Consider a `MovementSimulator.gd` static class if not already structured this way
- Use `NetConstants.gd` for `TICK_RATE`, `INTERPOLATION_DELAY`, `RECONCILIATION_EPSILON` — don't redefine them here

## Files to Create/Modify
```
scripts/net/ClientPrediction.gd
scripts/net/StateSnapshot.gd
scripts/net/RemoteInterpolation.gd
scripts/player/NetworkedPlayer.gd (update)
scripts/player/PlayerController.gd (ensure sim function is reusable)
tests/test_prediction_reconcile.tscn
tests/test_prediction_reconcile.gd
tests/test_remote_interpolation.tscn
tests/test_remote_interpolation.gd
```
