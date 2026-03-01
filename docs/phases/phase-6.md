# Phase 6: 8-Player Stability Pass + Net Debug Tools

## Status: NOT STARTED

## Prerequisites
- Phase 5 complete (full game loop working)

## Goal
Make it not fall apart when 8 people join and chaos happens. Add tools to diagnose and test network problems.

## Deliverables

### 1. Artificial Lag Simulator
Location: `res://scripts/net/LagSimulator.gd`

Host-controlled tool for testing under bad network conditions:
```gdscript
var simulated_latency_ms: float = 0.0  # One-way latency to add
var simulated_jitter_ms: float = 0.0   # Random variance
var simulated_packet_loss: float = 0.0  # 0.0 to 1.0 (percentage)

func should_drop_packet() -> bool
func get_delayed_send_time() -> float
```

Accessible from debug menu or console command.

### 2. Performance Counters
Add to debug overlay:
- **Bullets alive:** current count of active bullet nodes
- **RPC count/sec:** RPCs sent and received per second
- **Tick time:** milliseconds spent in `_physics_process`
- **Memory usage:** basic monitoring
- **Players connected:** count

### 3. Bullet Lifecycle Caps
Enforce hard limits to prevent performance degradation:
```gdscript
const MAX_BULLETS_PER_PLAYER: int = 10
const MAX_BULLETS_TOTAL: int = 80  # 8 players * 10
const BULLET_MAX_LIFETIME: float = 3.0  # seconds
const BULLET_MAX_DISTANCE: float = 2000.0  # pixels
```

- When a player exceeds their bullet cap, oldest bullet is removed
- Server enforces caps — clients cannot spawn more

### 4. Bandwidth Hygiene
Review and enforce:
- State snapshots sent at tick rate ONLY (not every frame)
- Snapshot data is minimal (only changed state, or at least compact)
- Don't send redundant data (e.g., skip snapshot if player hasn't moved)
- Consider delta compression (optional for MVP)
- Use `unreliable` for position updates, `reliable` for important events (kills, spawns)

### 5. Connection Management
- Server rejects 9th connection attempt (max 8 players)
- Graceful handling when player disconnects mid-game
- Timeout detection for unresponsive clients
- Clean up player nodes and bullets on disconnect

### 6. SoakTest.tscn - Stress Test Scene
Location: `res://scenes/SoakTest.tscn`

Automated stress test:
- Spawn 8 bot players (AI-controlled or scripted movement)
- Bots run around randomly and shoot
- Run for configurable duration (default 60 seconds)
- Monitor:
  - No errors in output log
  - Memory doesn't grow unbounded
  - Frame time stays reasonable
  - No orphaned nodes
  - Bullet count stays within caps

Bot behavior (simple):
```gdscript
# Each bot:
# - Pick random direction, move for 1-3 seconds
# - Jump occasionally
# - Shoot at nearest other player
# - Repeat
```

## Tests

### test_max_players_8.tscn / test_max_players_8.gd
- Start server
- Connect 8 clients sequentially
- Assert all 8 connect successfully
- Assert player count is 8
- Attempt to connect 9th client
- Assert 9th connection is rejected
- Assert player count remains 8

### test_bullet_caps.tscn / test_bullet_caps.gd
- Spawn a player and have them fire rapidly
- Assert bullet count does not exceed MAX_BULLETS_PER_PLAYER
- Assert oldest bullets are culled when cap is reached
- With multiple players: assert total bullets don't exceed MAX_BULLETS_TOTAL

### test_soak_60s.tscn / test_soak_60s.gd
- Run SoakTest scene for 60 seconds
- Assert: no errors printed to log
- Assert: bullet count stays within caps throughout
- Assert: player count remains stable (no phantom disconnects)
- Assert: memory growth is bounded (check at start and end)
- Assert: no orphaned nodes (scene tree node count is stable-ish)
- Print performance summary at end

## Optimization Checklist
- [ ] No allocations in hot loops (`_physics_process`)
- [ ] Bullet pooling (optional but recommended): reuse bullet objects instead of create/free
- [ ] String concatenation not used in hot paths
- [ ] RPC data is compact (use arrays instead of dictionaries where possible)
- [ ] Physics layers properly configured (bullets don't collide with each other)
- [ ] Debug draws disabled by default (only on F1 toggle)

## Phase Complete Checklist
- [ ] Lag simulator works and is accessible from debug menu
- [ ] Performance counters show on debug overlay
- [ ] Bullet caps enforced (per-player and total)
- [ ] Bandwidth is reasonable (snapshots at tick rate, minimal data)
- [ ] 9th player connection rejected gracefully
- [ ] Disconnect handling is clean (no orphaned nodes)
- [ ] SoakTest runs 60 seconds without errors
- [ ] test_max_players_8 — all PASS
- [ ] test_bullet_caps — all PASS
- [ ] test_soak_60s — all PASS
- [ ] Code review: network spam? Allocations in hot loops? Any leaks?
- [ ] Refactor: bullet pooling if needed
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Post-Phase 6: MVP Complete!
After this phase passes, the game meets MVP definition:
- Host creates match, others join by IP
- Up to 8 players move (predictive), shoot, take damage, die, respawn
- Deathmatch scoreboard works
- Test runner passes
- Debug overlay diagnoses net issues

## Files to Create/Modify
```
scripts/net/LagSimulator.gd
scenes/SoakTest.tscn
scripts/SoakTestBot.gd
scripts/Debug.gd (update with performance counters)
scripts/projectiles/ProjectileBullet.gd (add caps)
scripts/net/NetManager.gd (add max player rejection)
tests/test_max_players_8.tscn
tests/test_max_players_8.gd
tests/test_bullet_caps.tscn
tests/test_bullet_caps.gd
tests/test_soak_60s.tscn
tests/test_soak_60s.gd
```
