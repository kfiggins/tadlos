class_name Health
extends RefCounted

## Tracks player HP. Server-only for damage application.
## Pure logic class with no scene dependencies for testability.

signal health_changed(new_hp: int, max_hp: int)
signal died(killer_peer_id: int)

var max_hp: int = 100
var current_hp: int = 100


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int, source_peer_id: int) -> void:
	if current_hp <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit(source_peer_id)


func heal(amount: int) -> void:
	if current_hp <= 0:
		return
	current_hp = mini(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func reset() -> void:
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
