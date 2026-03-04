# Tadlos Architecture Overview

## Scene Tree (GameWorld.tscn)
```
GameWorld (Node2D)                    scripts/GameWorld.gd
  Players (Node)                      NetworkedPlayer instances, named by str(peer_id)
  Bullets (Node)                      ProjectileBullet instances
  SpawnMarkers (Node2D)               10x Marker2D children
  GameModeDeathmatch (Node)           Server-authoritative scoring/respawn
  PlayerSpawner (Node)                Spawns/despawns players and bots
  Floor (StaticBody2D)                pos=(3000,1016), 6000x32
  GroundPlat1-4 (StaticBody2D)        y=850-870, 300px wide, near floor
  MidPlat1-6 (StaticBody2D)           y=590-660, 300px wide, mid level
  HighPlat1-5 (StaticBody2D)          y=380-440, 300px wide, high level
  TopPlat1-3 (StaticBody2D)           y=170-200, 200-300px wide, top level
  WallLeft (StaticBody2D)             pos=(-100,500), 32x1200
  WallRight (StaticBody2D)            pos=(6100,500), 32x1200
```

## Map Geometry
- Playable area: X ~[-84, 6084], floor surface at Y ~1000
- 18 platforms across 4 tiers: ground (y~850), mid (y~600), high (y~400), top (y~180)
- 10 spawn points spread across all tiers and horizontal positions

## Autoloads
- **Assert** (`scripts/Assert.gd`) -- test assertions
- **Debug** (`scripts/Debug.gd`) -- F1 overlay, logging, perf counters
- **NetManager** (`scripts/net/NetManager.gd`) -- ENet host/join, peer tracking, lag simulator

## Key Scripts

### Networking (`scripts/net/`)
| Script | Role |
|--------|------|
| NetConstants.gd | TICK_RATE=30, MAX_PLAYERS=8, DEFAULT_PORT=7777, bullet caps |
| NetManager.gd | Host/join, peer connect/disconnect signals, requested_bot_count |
| PlayerSpawner.gd | Spawn/despawn players + bots, RPC replication to clients |
| ClientPrediction.gd | RefCounted, input buffer + reconciliation (pure logic) |
| RemoteInterpolation.gd | RefCounted, snapshot buffer + lerp (pure logic) |
| LagSimulator.gd | RefCounted, artificial latency/jitter/packet loss |

### Player (`scripts/player/`)
| Script | Role |
|--------|------|
| NetworkedPlayer.gd | CharacterBody2D, 3 modes: server sim / client predict / client interpolate |
| PlayerController.gd | Static `calculate_velocity()` + `sample_input_at()` (pure logic) |
| MovementTuning.gd | Constants: MAX_SPEED=300, JUMP=-600, GRAVITY=980, JETPACK=-1500 |
| Health.gd | RefCounted, HP tracking, died/health_changed signals |
| HUD.gd | CanvasLayer: ammo, HP bar, death screen, scoreboard (Tab), kill feed |

### Weapons & Projectiles
| Script | Role |
|--------|------|
| WeaponConfig.gd | Resource: bullet_speed=1000, damage=25, fire_rate=0.15, max_ammo=30 |
| WeaponRifle.gd | RefCounted, cooldown/ammo/reload logic |
| ProjectileBullet.gd | CharacterBody2D, server-authoritative, move_and_collide, hit signals |

### Game Mode
| Script | Role |
|--------|------|
| GameModeDeathmatch.gd | Server-only: scores, respawn timers (3s), kill tracking, spawn selection |
| SpawnPoints.gd | RefCounted, avoidance-based spawn selection (pure logic) |

### Bot (`scripts/bot/`)
| Script | Role |
|--------|------|
| BotAI.gd | Smart bot: state machine (IDLE/PURSUE/ENGAGE/RETREAT) |
| BotConstants.gd | BOT_PEER_ID_START=100, MAX_BOTS=7 |
| SoakTestBot.gd | Simple random bot for soak/stress testing (in scripts/) |

## Data Flow
1. Host calls `NetManager.host()` -> scene changes to GameWorld
2. `PlayerSpawner._ready()` spawns host player (peer 1) + requested bots
3. Client connects -> `PlayerSpawner._server_client_ready()` spawns client player + replicates all existing players
4. Each tick (30 Hz): server simulates all players, broadcasts state via `_receive_state.rpc()`
5. Clients: predict local player, interpolate remote players (including bots)
6. Bullets: server spawns + simulates + hit detection; clients get cosmetic copies via `_on_fire_event.rpc()`
7. Deaths: `Health.died` -> `NetworkedPlayer._on_player_died` -> `GameModeDeathmatch.on_player_killed` -> 3s timer -> respawn

## Input Dictionary Format
```gdscript
{move_dir: float, jump: bool, jetpack: bool, dive: bool, aim_angle: float, seq: int}
```
Bots inject input via `player.set_bot_input(input)` + `player._bot_wants_fire = true`.

## Player Naming Convention
Player nodes in the `Players` container are named `str(peer_id)`. Bots use fake peer IDs starting at 100.
