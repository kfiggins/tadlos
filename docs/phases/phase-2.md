# Phase 2: Networking Foundation (Host/Join + Replicated Players)

## Status: NOT STARTED

## Prerequisites
- Phase 0 complete (test harness)
- Phase 1 complete (local movement works)

## Goal
Two machines (or two instances) can Host and Join by IP. Players spawn and move around. Movement replication can be simple for now, but structure it so prediction can be added in Phase 3.

## Implementation Approach
1. Host starts `ENetMultiplayerPeer` server
2. Join connects as client
3. Server spawns player nodes and assigns authority
4. Client sends input to server (RPC) — capped at `MAX_INPUT_RATE` (1 per tick)
5. Server simulates player movement at `TICK_RATE` Hz
6. Server sends snapshots to clients at `SNAPSHOT_RATE` Hz

### Network Constants (define in this phase)
Create `res://scripts/net/NetConstants.gd` with shared values. See CLAUDE.md "Network Constants" section for the full list. Key values:
- `TICK_RATE = 30` — server sim rate
- `SNAPSHOT_RATE = 30` — state broadcast rate
- `MAX_INPUT_RATE = 30` — max input RPCs per second from a client
- `MAX_PLAYERS = 8`
- `DEFAULT_PORT = 7777`

### Input Payload Format (first pass)
```gdscript
# Client → Server (per tick)
var input_payload := {
    "seq": int,          # Incrementing sequence number
    "move_dir": float,   # -1.0 to 1.0
    "jump": bool,
    "jetpack": bool,
    "dive": bool,
    "aim_angle": float,  # Radians
}
```
Keep this compact. No strings, no nested objects. This format is used from Phase 2 onward.

## Deliverables

### 1. NetManager.gd
Location: `res://scripts/net/NetManager.gd`

Autoload singleton managing network state.

```gdscript
# Core functions
func host(port: int) -> Error
func join(ip: String, port: int) -> Error
func disconnect_peer() -> void

# Signals
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

# State
var is_host: bool
var local_peer_id: int
var connected_peers: Array[int]
```

Key behaviors:
- On host: listen on port, handle peer connections
- On join: connect to ip:port
- Track connected peers
- Handle disconnections gracefully
- Max players check (reject if >= 8)

### 2. PlayerSpawner.gd
Location: `res://scripts/net/PlayerSpawner.gd`

Handles spawning/despawning player nodes:
- On `player_connected`: spawn a player node for that peer
- On `player_disconnected`: remove that peer's player node
- Assign `set_multiplayer_authority()` appropriately
- Use `MultiplayerSpawner` node or manual spawn + RPC

### 3. NetworkedPlayer.gd
Location: `res://scripts/player/NetworkedPlayer.gd`

Wraps PlayerController for networked play:
- If local player (has authority): sample input, send to server
- If server: receive input, run simulation, broadcast state
- If remote player on client: receive state updates, apply position

For MVP (before prediction in Phase 3):
- Client sends input each tick via RPC
- Server processes input and moves the player
- Server sends position/velocity snapshots to all clients
- Remote players just snap to received positions (interpolation comes in Phase 3)

### 4. Update Main.tscn Menu
- Host button: prompt for port (or use default 7777), call `NetManager.host()`
- Join button: prompt for IP + port, call `NetManager.join()`
- Show connection status

### 5. NetDebugOverlay
Add to debug overlay (or new overlay):
- `is_host` (true/false)
- `peer_id` (local peer ID)
- `players_connected` (count)
- Toggle with F2 or add to F1 overlay

## RPC Design

### Client → Server
```gdscript
@rpc("any_peer", "reliable")
func receive_player_input(input_data: Dictionary) -> void
    # Validate sender: multiplayer.get_remote_sender_id()
    # Only accept input for the sender's own player
```

### Server → Clients
```gdscript
@rpc("authority", "unreliable")
func receive_state_snapshot(snapshot: Dictionary) -> void
    # Contains: {peer_id, position, velocity, grounded, tick}
```

## RPC Security Rules
- Always validate `multiplayer.get_remote_sender_id()` matches expected peer
- Server never trusts client position/velocity — only input
- Rate-limit input RPCs (one per tick max)
- Validate input values are within expected ranges

## Tests

### test_host_join.tscn / test_host_join.gd
- Create server `ENetMultiplayerPeer` on port
- Create client `ENetMultiplayerPeer`, connect to localhost:port
- Wait for connection signals
- Assert both see connection
- Assert player count increments on both sides
- Assert host's own player (peer_id 1) is spawned and playable (host is both server and client)
- Clean up peers

### test_spawn_authority.tscn / test_spawn_authority.gd
- Set up host + client connection
- Assert server is authority for world/game objects
- Assert each player node has correct multiplayer authority
- Assert client cannot call server-only RPCs (or they are rejected)

### test_disconnect_cleanup.tscn / test_disconnect_cleanup.gd
- Set up host + 2 clients
- Disconnect one client
- Assert disconnected player's node is removed from scene tree on all peers
- Assert remaining player count is correct (host + 1 client)
- Assert no orphaned nodes from the disconnected player (bullets, effects, etc.)

### test_late_join.tscn / test_late_join.gd
- Set up host + 1 client, let them move around briefly
- Connect a second client (late joiner)
- Assert late joiner sees all existing players
- Assert late joiner's player is visible to all existing peers
- Assert late joiner receives current world state (player positions)

## Phase Complete Checklist
- [ ] NetManager.gd handles host/join/disconnect
- [ ] PlayerSpawner.gd spawns/despawns players on connect/disconnect
- [ ] NetworkedPlayer.gd wraps movement for network play
- [ ] Two instances can connect and see each other move
- [ ] Main menu Host/Join buttons work
- [ ] Net debug overlay shows connection info
- [ ] test_host_join — all PASS (including host player behavior)
- [ ] test_spawn_authority — all PASS
- [ ] test_disconnect_cleanup — all PASS
- [ ] test_late_join — all PASS
- [ ] Code review: RPC sender validation? No client-trusted state? Clean separation?
- [ ] Refactor: isolate net messages if needed
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Architecture Notes
- The input → simulate → broadcast pattern established here is the foundation for Phase 3 prediction
- Keep the velocity calculation from Phase 1 deterministic and shared — collision resolution via `move_and_slide()` is scene-dependent (see Phase 1 architecture notes)
- Server maintains authoritative tick counter that increments each `_physics_process`
- Network constants must be shared between client and server (use `NetConstants.gd`)
- Snapshot and input rates are capped from the start — don't defer bandwidth discipline to Phase 6

## Files to Create/Modify
```
scripts/net/NetManager.gd
scripts/net/NetConstants.gd
scripts/net/PlayerSpawner.gd
scripts/player/NetworkedPlayer.gd
scenes/Main.tscn (update menu)
scenes/GameWorld.tscn (networked game scene)
tests/test_host_join.tscn
tests/test_host_join.gd
tests/test_spawn_authority.tscn
tests/test_spawn_authority.gd
tests/test_disconnect_cleanup.tscn
tests/test_disconnect_cleanup.gd
tests/test_late_join.tscn
tests/test_late_join.gd
project.godot (autoload NetManager)
```
