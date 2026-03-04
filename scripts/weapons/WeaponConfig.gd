class_name WeaponConfig
extends Resource

## Resource class for weapon statistics.
## Create instances for each weapon type with different stats.

enum FireMode { SEMI_AUTO, FULL_AUTO }

@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export var damage: int = 25
@export var fire_rate: float = 0.35  # seconds between shots
@export var bullet_speed: float = 900.0
@export var bullet_gravity: float = 200.0
@export var max_ammo: int = 8
@export var reload_time: float = 1.5
@export var max_range: float = 1200.0  # max bullet travel distance in pixels


## Returns true if the weapon requires a fresh click/press per shot.
func is_semi_auto() -> bool:
	return fire_mode == FireMode.SEMI_AUTO


## Create a pistol weapon config (current default).
static func pistol() -> WeaponConfig:
	return WeaponConfig.new()


## Create a rifle weapon config (for future use).
static func rifle() -> WeaponConfig:
	var config := WeaponConfig.new()
	config.fire_mode = FireMode.FULL_AUTO
	config.damage = 20
	config.fire_rate = 0.12
	config.bullet_speed = 1200.0
	config.bullet_gravity = 50.0
	config.max_ammo = 30
	config.reload_time = 2.0
	config.max_range = 2000.0
	return config
