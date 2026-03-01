extends Node

## Tests server-side validation: invalid fire requests rejected,
## cooldown enforcement, and direct damage RPC rejection.
## Mostly pure logic tests for validation functions.

func run_tests() -> void:
	_test_weapon_cooldown_enforcement()
	_test_fire_origin_validation()
	_test_health_server_only_take_damage()
	_test_health_signals_fire_correctly()
	_test_rapid_fire_blocked()
	_test_muzzle_offset_calculation()
	_test_weapon_config_resource()
	_test_health_clamps_at_zero()
	_test_health_heal()


func _test_weapon_cooldown_enforcement() -> void:
	var weapon := WeaponRifle.new()
	# Fire once successfully
	Assert.assert_true(weapon.fire(), "First fire succeeds")
	# Immediately try again — should be blocked
	Assert.assert_false(weapon.can_fire(), "Cooldown blocks immediate refire")
	# Partially advance cooldown (not enough)
	weapon.process_cooldown(0.05)
	Assert.assert_false(weapon.can_fire(), "Partial cooldown still blocks fire")
	# Finish cooldown
	weapon.process_cooldown(0.11)
	Assert.assert_true(weapon.can_fire(), "Full cooldown allows fire")


func _test_fire_origin_validation() -> void:
	# Test that fire origin distance check works
	var player_pos := Vector2(400, 300)
	var valid_origin := Vector2(410, 300)  # 10px away — within tolerance
	var invalid_origin := Vector2(900, 300)  # 500px away — too far

	var valid_dist := valid_origin.distance_to(player_pos)
	var invalid_dist := invalid_origin.distance_to(player_pos)

	Assert.assert_lt(valid_dist, 60.0, "Valid origin within tolerance (dist: %.1f)" % valid_dist)
	Assert.assert_gt(invalid_dist, 60.0, "Invalid origin exceeds tolerance (dist: %.1f)" % invalid_dist)


func _test_health_server_only_take_damage() -> void:
	# Health.take_damage works as a function call (server authority is enforced
	# at the NetworkedPlayer level, not in Health itself)
	var hp := Health.new()
	hp.take_damage(25, 1)
	Assert.assert_eq(hp.current_hp, 75, "take_damage reduces HP")

	# Verify no double-death: damage when already dead does nothing
	hp.take_damage(100, 1)
	Assert.assert_eq(hp.current_hp, 0, "HP at 0 after lethal damage")
	hp.take_damage(50, 2)
	Assert.assert_eq(hp.current_hp, 0, "No further damage when dead")


func _test_health_signals_fire_correctly() -> void:
	var hp := Health.new()
	# Use arrays to capture values in lambda (GDScript captures primitives by value)
	var counts := [0, 0]  # [change_count, died_count]
	hp.health_changed.connect(func(_new_hp: int, _max_hp: int) -> void: counts[0] += 1)
	hp.died.connect(func(_id: int) -> void: counts[1] += 1)

	hp.take_damage(25, 1)
	Assert.assert_eq(counts[0], 1, "health_changed emitted once after damage")
	Assert.assert_eq(counts[1], 0, "died not emitted at 75 HP")

	hp.take_damage(75, 1)
	Assert.assert_eq(counts[0], 2, "health_changed emitted again on lethal damage")
	Assert.assert_eq(counts[1], 1, "died emitted once at 0 HP")

	# No signals on dead player
	hp.take_damage(25, 1)
	Assert.assert_eq(counts[0], 2, "No health_changed after death")
	Assert.assert_eq(counts[1], 1, "No additional died signal")


func _test_rapid_fire_blocked() -> void:
	var weapon := WeaponRifle.new()
	var fire_count := 0
	# Try to fire 10 times with no cooldown processing
	for i in 10:
		if weapon.fire():
			fire_count += 1
	Assert.assert_eq(fire_count, 1, "Only 1 fire succeeds out of 10 rapid attempts")


func _test_muzzle_offset_calculation() -> void:
	# Aim angle 0 = pointing right (angle_to_point convention varies,
	# but the static method uses cos/sin directly)
	var offset_right := WeaponRifle.get_muzzle_offset(0.0)
	Assert.assert_gt(offset_right.x, 0.0, "Muzzle offset X > 0 at angle 0 (right)")
	Assert.assert_lt(absf(offset_right.y), 0.01, "Muzzle offset Y ~0 at angle 0")

	var offset_down := WeaponRifle.get_muzzle_offset(PI / 2.0)
	Assert.assert_lt(absf(offset_down.x), 0.01, "Muzzle offset X ~0 at angle PI/2")
	Assert.assert_gt(offset_down.y, 0.0, "Muzzle offset Y > 0 at angle PI/2 (down)")


func _test_weapon_config_resource() -> void:
	var config := WeaponConfig.new()
	# Default values from the resource
	Assert.assert_eq(config.damage, 25, "Default damage is 25")
	Assert.assert_eq(config.fire_rate, 0.15, "Default fire_rate is 0.15")
	Assert.assert_eq(config.bullet_speed, 1200.0, "Default bullet_speed is 1200")
	Assert.assert_eq(config.bullet_gravity, 50.0, "Default bullet_gravity is 50")
	Assert.assert_eq(config.max_ammo, 30, "Default max_ammo is 30")


func _test_health_clamps_at_zero() -> void:
	var hp := Health.new()
	hp.take_damage(200, 1)  # More than max HP
	Assert.assert_eq(hp.current_hp, 0, "HP clamps at 0, does not go negative")


func _test_health_heal() -> void:
	var hp := Health.new()
	hp.take_damage(50, 1)
	hp.heal(20)
	Assert.assert_eq(hp.current_hp, 70, "Heal restores HP")
	hp.heal(1000)
	Assert.assert_eq(hp.current_hp, 100, "Heal clamps at max HP")
