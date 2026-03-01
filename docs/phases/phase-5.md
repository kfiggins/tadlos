# Phase 5: Respawn Loop + Scoring + Basic Game Rules

## Status: NOT STARTED

## Prerequisites
- Phase 4 complete (weapons + damage working)

## Goal
Now it's a game loop: spawn → shoot → die → respawn → track kills/deaths.

## Deliverables

### 1. GameModeDeathmatch.gd
Location: `res://scripts/GameModeDeathmatch.gd`

Server-authoritative game mode manager:
```gdscript
# Game state
var scores: Dictionary = {}  # {peer_id: {kills: int, deaths: int}}
var game_active: bool = false

# Configuration
var respawn_delay: float = 3.0
var kill_limit: int = 0  # 0 = no limit (time-based or infinite)

func on_player_killed(killer_id: int, victim_id: int) -> void:
    # Increment killer's kills
    # Increment victim's deaths
    # Start respawn timer for victim
    # Broadcast score update to all clients

func respawn_player(peer_id: int) -> void:
    # Choose spawn point
    # Reset HP
    # Re-enable input
    # Broadcast spawn to all clients
```

### 2. SpawnPoints System
Location: `res://scripts/SpawnPoints.gd`

```gdscript
# Manage spawn point selection
var spawn_points: Array[Vector2] = []

func get_spawn_point() -> Vector2:
    # Choose a valid spawn point
    # Avoid spawning inside walls (validate with physics query)
    # Prefer points far from other players (optional for MVP)
    # Return position
```

Spawn points placed as `Marker2D` nodes in the game world scene.

### 3. Death + Respawn Flow
On player death (HP reaches 0):
1. **Server:** Mark player as dead, disable collision
2. **Server → Clients:** Send death event (killer_id, victim_id, position)
3. **Client:** Play death effect (ragdoll placeholder or simple animation)
4. **Client:** Disable input for dead player
5. **Server:** Start respawn timer (3 seconds)
6. **Server:** After timer, call `respawn_player()`
7. **Server → Clients:** Send respawn event with new position
8. **Client:** Re-enable input, show player at spawn point

### 4. Scoreboard UI
Location: `res://scenes/Scoreboard.tscn`

Toggle with Tab key:
```
Name          | Kills | Deaths | Ping
--------------+-------+--------+------
Player1       |   5   |   2    | 45ms
Player2       |   3   |   4    | 67ms
...
```

- Updated via RPC from server when scores change
- Ping can be approximate for now (or placeholder)
- Sorted by kills (descending)

### 5. Kill Feed (Optional but nice)
Simple text notifications at top of screen:
- "Player1 killed Player2"
- Fade out after 3-5 seconds
- Show last 5 kills

### 6. Death Screen
When local player dies:
- Gray out / darken screen
- Show "You were killed by [PlayerName]"
- Show respawn countdown: "Respawning in 3... 2... 1..."

## Game State Replication
- Scores are server-authoritative
- Server sends full score update on:
  - Player connects (send current scores)
  - Kill happens (send updated scores)
- Client scoreboard is read-only display

## Tests

### test_respawn_timer.tscn / test_respawn_timer.gd
- Kill a player (set HP to 0)
- Assert player is marked as dead
- Assert player cannot move/shoot while dead
- Wait respawn_delay seconds (simulate ticks)
- Assert player respawns with full HP
- Assert player can move again after respawn

### test_scoring_on_kill.tscn / test_scoring_on_kill.gd
- Set up two players (or mock player data)
- Player A kills Player B
- Assert Player A's kill count incremented by 1
- Assert Player B's death count incremented by 1
- Assert scores dictionary is consistent
- Kill Player B again
- Assert counts are now kills=2, deaths=2

### test_spawn_safety.tscn / test_spawn_safety.gd
- Set up spawn points, including some near walls
- Call `get_spawn_point()` multiple times
- Assert returned position is not inside a wall (physics overlap test)
- Assert returned position is a valid spawn point
- If using "far from players" logic: assert spawn point has minimum distance from other players

## Phase Complete Checklist
- [ ] GameModeDeathmatch.gd manages kill/death scoring
- [ ] SpawnPoints system selects valid spawn locations
- [ ] Death flow: disable → death effect → timer → respawn
- [ ] Respawn restores full HP and re-enables input
- [ ] Scoreboard UI shows kills/deaths/ping, toggles with Tab
- [ ] All rules are server-authoritative
- [ ] test_respawn_timer — all PASS
- [ ] test_scoring_on_kill — all PASS
- [ ] test_spawn_safety — all PASS
- [ ] Code review: rules all server-side? Scoreboard replicated cleanly?
- [ ] Refactor: separate GameState replication from UI
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Files to Create/Modify
```
scripts/GameModeDeathmatch.gd
scripts/SpawnPoints.gd
scenes/Scoreboard.tscn
scenes/Scoreboard.gd
scenes/DeathScreen.tscn (or part of HUD)
scenes/GameWorld.tscn (add spawn point markers)
scripts/player/Health.gd (update for respawn)
scripts/player/NetworkedPlayer.gd (death/respawn state)
tests/test_respawn_timer.tscn
tests/test_respawn_timer.gd
tests/test_scoring_on_kill.tscn
tests/test_scoring_on_kill.gd
tests/test_spawn_safety.tscn
tests/test_spawn_safety.gd
```
