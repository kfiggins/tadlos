class_name WeaponConfig
extends Resource

## Resource class for weapon statistics.
## Create instances for each weapon type with different stats.

@export var damage: int = 25
@export var fire_rate: float = 0.15  # seconds between shots
@export var bullet_speed: float = 1200.0
@export var bullet_gravity: float = 50.0
@export var max_ammo: int = 30
@export var reload_time: float = 2.0
