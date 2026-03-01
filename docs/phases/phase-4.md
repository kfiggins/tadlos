# Phase 4: Projectile Weapons MVP (Server-Authoritative)

## Status: DONE

## Prerequisites
- Phase 3 complete (prediction + reconciliation working)

## Goal
One weapon: **Rifle**. Fires projectile bullets like Soldat: fast, small, minimal gravity. Server is authoritative for hit detection and damage. Clients show effects immediately (predicted firing), but server confirms hits.

## Implementation Notes

### Firing Flow
1. **Client presses fire:**
   - Client spawns local tracer/muzzle flash immediately (cosmetic prediction)
   - Sends `fire_request(seq, origin, direction)` to server via RPC

2. **Server validates:**
   - Fire rate cooldown has elapsed
   - Ammo check (if applicable)
   - Origin position is plausible (anti-cheat: within reasonable distance of server's known player position)

3. **Server spawns authoritative bullet:**
   - Bullet moves each physics tick
   - Collision test vs world geometry + player hitboxes
   - On hit: apply damage, send hit event to all clients

### Bullet Simulation
- Move bullet by `velocity * delta` each tick
- Apply minimal gravity (optional, can start with zero)
- Check collision via raycast or shape cast per tick
- Despawn on: wall hit, player hit, max lifetime, max distance

### Damage Model (MVP)
- Player HP: 100
- Rifle damage: 25 per hit
- No armor, no headshots for MVP
- Death at 0 HP

## Deliverables

### 1. WeaponRifle.gd
Location: `res://scripts/weapons/WeaponRifle.gd`

```gdscript
# Configuration (use Resource or constants)
var damage: int = 25
var fire_rate: float = 0.15  # seconds between shots
var bullet_speed: float = 1200.0
var bullet_gravity: float = 50.0  # minimal
var max_ammo: int = 30  # or infinite for MVP
var reload_time: float = 2.0

# State
var cooldown_timer: float = 0.0
var current_ammo: int = max_ammo

func can_fire() -> bool
func fire(origin: Vector2, direction: Vector2) -> void
func _process_cooldown(delta: float) -> void
```

### 2. ProjectileBullet.gd
Location: `res://scripts/projectiles/ProjectileBullet.gd`

```gdscript
var velocity: Vector2
var owner_peer_id: int
var damage: int
var lifetime: float = 3.0
var gravity: float = 50.0

func _physics_process(delta: float) -> void:
    # Move
    # Apply gravity
    # Check collisions
    # Despawn if lifetime exceeded or hit something
```

Bullet scene: lightweight node (Area2D or just position + raycast per tick)

### 3. Health.gd
Location: `res://scripts/player/Health.gd`

```gdscript
signal health_changed(new_hp: int, max_hp: int)
signal died(killer_peer_id: int)

var max_hp: int = 100
var current_hp: int = 100

func take_damage(amount: int, source_peer_id: int) -> void:
    # Server-only function
    # Reduce HP
    # Emit signals
    # If HP <= 0: emit died
```

### 4. HitEvent RPC
Server → All Clients:
```gdscript
@rpc("authority", "reliable")
func on_hit_event(data: Dictionary) -> void:
    # data = {victim_id, shooter_id, position, damage}
    # Spawn blood puff effect
    # Play hit sound (placeholder)
```

### 5. HUD Elements
- Crosshair (simple + centered)
- HP bar or number display
- Ammo counter (if using ammo)

### 6. Weapon Config Resource (Refactor Target)
```gdscript
class_name WeaponConfig extends Resource

@export var damage: int
@export var fire_rate: float
@export var bullet_speed: float
@export var bullet_gravity: float
@export var max_ammo: int
@export var reload_time: float
```

## RPC Security for Weapons
- `fire_request` is client → server: validate sender, check cooldown server-side
- Server tracks each player's last fire time independently
- Server validates bullet origin is near player's server-known position
- Damage is ONLY applied by server — never trust a client "I hit someone" RPC
- Hit detection runs entirely on server

## Tests

### test_weapon_cooldown.tscn / test_weapon_cooldown.gd
- Create WeaponRifle instance
- Call `fire()` — should succeed
- Immediately call `fire()` again — should fail (cooldown not elapsed)
- Wait cooldown duration
- Call `fire()` again — should succeed
- Assert fire count matches expected (2, not 3)

### test_projectile_hits_player.tscn / test_projectile_hits_player.gd
- Spawn a bullet aimed at a stationary player
- Run physics ticks until collision
- Assert player HP decreased by bullet damage
- Assert `died` signal emits when HP reaches 0 (fire 4 shots at 25 damage each)

### test_projectile_world_collision.tscn / test_projectile_world_collision.gd
- Spawn a bullet aimed at a wall
- Run physics ticks
- Assert bullet despawns/is freed on wall contact
- Assert bullet does not pass through wall

### test_desync_safety.tscn / test_desync_safety.gd
- Simulate a malicious client sending a `fire_request` with:
  - Invalid origin (far from player's actual position) — should be rejected
  - Too-fast fire rate (ignoring cooldown) — server should enforce cooldown
  - Fake damage RPC (client trying to directly call take_damage) — should be rejected
- Assert: server state is not corrupted by invalid requests

## Phase Complete Checklist
- [ ] WeaponRifle.gd handles firing, cooldown, ammo
- [ ] ProjectileBullet.gd moves, collides, despawns correctly
- [ ] Health.gd tracks HP, emits damage/death signals
- [ ] Hit detection is server-authoritative only
- [ ] Client sees predicted muzzle flash / tracer
- [ ] HUD shows crosshair + HP
- [ ] test_weapon_cooldown — all PASS
- [ ] test_projectile_hits_player — all PASS
- [ ] test_projectile_world_collision — all PASS
- [ ] test_desync_safety — all PASS
- [ ] Code review: server authority enforced? No client-driven state? Cooldown on server?
- [ ] Refactor: weapon config into Resource
- [ ] Run all tests again — all PASS
- [ ] Update Phase Tracker in CLAUDE.md to DONE

## Files to Create/Modify
```
scripts/weapons/WeaponRifle.gd
scripts/weapons/WeaponConfig.gd (Resource)
scripts/projectiles/ProjectileBullet.gd
scripts/player/Health.gd
scenes/Bullet.tscn
scenes/Player.tscn (add weapon + health nodes)
scenes/HUD.tscn (crosshair + HP)
tests/test_weapon_cooldown.tscn
tests/test_weapon_cooldown.gd
tests/test_projectile_hits_player.tscn
tests/test_projectile_hits_player.gd
tests/test_projectile_world_collision.tscn
tests/test_projectile_world_collision.gd
tests/test_desync_safety.tscn
tests/test_desync_safety.gd
```
