class_name WeaponRifle
extends RefCounted

## Rifle weapon with fire rate cooldown and ammo tracking.
## Pure logic class — no scene dependencies for testability.
## Server tracks authoritative cooldown; client tracks local prediction cooldown.

var config: WeaponConfig

var cooldown_timer: float = 0.0
var current_ammo: int = 0


func _init(weapon_config: WeaponConfig = null) -> void:
	if weapon_config == null:
		config = WeaponConfig.new()
	else:
		config = weapon_config
	current_ammo = config.max_ammo


func can_fire() -> bool:
	return cooldown_timer <= 0.0 and current_ammo > 0


func fire() -> bool:
	if not can_fire():
		return false
	cooldown_timer = config.fire_rate
	current_ammo -= 1
	return true


func process_cooldown(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer < 0.0:
			cooldown_timer = 0.0


## Distance from player center to muzzle origin.
const MUZZLE_DISTANCE := 20.0

## Returns the muzzle origin offset from player center given an aim angle.
static func get_muzzle_offset(aim_angle: float) -> Vector2:
	return Vector2(cos(aim_angle), sin(aim_angle)) * MUZZLE_DISTANCE

## Returns the aim direction unit vector from an aim angle.
static func get_aim_direction(aim_angle: float) -> Vector2:
	return Vector2(cos(aim_angle), sin(aim_angle))
