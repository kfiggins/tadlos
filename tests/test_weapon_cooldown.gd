extends Node

## Tests WeaponRifle cooldown, firing, and ammo logic.
## Pure logic tests — no scene or physics dependencies.

func run_tests() -> void:
	_test_can_fire_initially()
	_test_fire_succeeds()
	_test_cooldown_blocks_immediate_refire()
	_test_cooldown_elapses_allows_fire()
	_test_ammo_decrements()
	_test_empty_ammo_blocks_fire()
	_test_fire_count_matches_expected()
	_test_config_values_apply()
	_test_auto_reload_starts_on_empty()
	_test_reload_blocks_fire()
	_test_reload_completes_and_refills()
	_test_health_take_damage()
	_test_health_death_at_zero()
	_test_health_no_damage_when_dead()
	_test_health_reset()


func _test_can_fire_initially() -> void:
	var weapon := WeaponRifle.new()
	Assert.assert_true(weapon.can_fire(), "Weapon can fire initially")


func _test_fire_succeeds() -> void:
	var weapon := WeaponRifle.new()
	var result := weapon.fire()
	Assert.assert_true(result, "First fire returns true")


func _test_cooldown_blocks_immediate_refire() -> void:
	var weapon := WeaponRifle.new()
	weapon.fire()
	Assert.assert_false(weapon.can_fire(), "Cannot fire during cooldown")
	var result := weapon.fire()
	Assert.assert_false(result, "Fire returns false during cooldown")


func _test_cooldown_elapses_allows_fire() -> void:
	var weapon := WeaponRifle.new()
	weapon.fire()
	# Advance cooldown past fire_rate (0.35s)
	weapon.process_cooldown(0.36)
	Assert.assert_true(weapon.can_fire(), "Can fire after cooldown elapses")
	var result := weapon.fire()
	Assert.assert_true(result, "Fire succeeds after cooldown")


func _test_ammo_decrements() -> void:
	var weapon := WeaponRifle.new()
	var initial_ammo := weapon.current_ammo
	weapon.fire()
	Assert.assert_eq(weapon.current_ammo, initial_ammo - 1, "Ammo decrements by 1 after fire")


func _test_empty_ammo_blocks_fire() -> void:
	var weapon := WeaponRifle.new()
	weapon.current_ammo = 0
	Assert.assert_false(weapon.can_fire(), "Cannot fire with 0 ammo")
	var result := weapon.fire()
	Assert.assert_false(result, "Fire returns false with 0 ammo")


func _test_fire_count_matches_expected() -> void:
	var weapon := WeaponRifle.new()
	# Fire, fail immediately, wait cooldown, fire again = 2 successful fires
	var fire_count := 0
	if weapon.fire():
		fire_count += 1
	if weapon.fire():
		fire_count += 1  # Should fail
	weapon.process_cooldown(0.36)
	if weapon.fire():
		fire_count += 1
	Assert.assert_eq(fire_count, 2, "Fire count is 2 (not 3): cooldown blocked one attempt")


func _test_config_values_apply() -> void:
	var config := WeaponConfig.new()
	config.damage = 50
	config.fire_rate = 0.5
	config.bullet_speed = 800.0
	var weapon := WeaponRifle.new(config)
	Assert.assert_eq(weapon.config.damage, 50, "Custom damage applied")
	Assert.assert_eq(weapon.config.fire_rate, 0.5, "Custom fire_rate applied")
	Assert.assert_eq(weapon.config.bullet_speed, 800.0, "Custom bullet_speed applied")


# --- Reload tests ---

func _test_auto_reload_starts_on_empty() -> void:
	var config := WeaponConfig.new()
	config.max_ammo = 1
	var weapon := WeaponRifle.new(config)
	weapon.fire()
	Assert.assert_eq(weapon.current_ammo, 0, "Ammo is 0 after firing last round")
	Assert.assert_true(weapon.reloading, "Auto-reload started when magazine emptied")


func _test_reload_blocks_fire() -> void:
	var config := WeaponConfig.new()
	config.max_ammo = 1
	config.reload_time = 2.0
	var weapon := WeaponRifle.new(config)
	weapon.fire()
	weapon.process_cooldown(0.36)  # Clear fire cooldown
	Assert.assert_false(weapon.can_fire(), "Cannot fire while reloading")
	Assert.assert_false(weapon.fire(), "Fire returns false while reloading")


func _test_reload_completes_and_refills() -> void:
	var config := WeaponConfig.new()
	config.max_ammo = 30
	config.reload_time = 2.0
	var weapon := WeaponRifle.new(config)
	# Empty the magazine
	for i in range(30):
		weapon.process_cooldown(0.36)
		weapon.fire()
	Assert.assert_true(weapon.reloading, "Reloading after emptying magazine")
	Assert.assert_eq(weapon.current_ammo, 0, "Ammo is 0 during reload")
	# Partially advance reload
	weapon.process_cooldown(1.0)
	Assert.assert_true(weapon.reloading, "Still reloading at 1s of 2s")
	# Complete reload
	weapon.process_cooldown(1.1)
	Assert.assert_false(weapon.reloading, "Reload complete after 2+ seconds")
	Assert.assert_eq(weapon.current_ammo, 30, "Ammo refilled to max after reload")
	Assert.assert_true(weapon.can_fire(), "Can fire after reload completes")


# --- Health tests (included here since they're pure logic) ---

func _test_health_take_damage() -> void:
	var hp := Health.new()
	hp.take_damage(25, 1)
	Assert.assert_eq(hp.current_hp, 75, "HP decreases by damage amount")
	Assert.assert_true(hp.is_alive(), "Still alive at 75 HP")


func _test_health_death_at_zero() -> void:
	var hp := Health.new()
	# Use array to capture values in lambda (GDScript captures primitives by value)
	var result := [false, -1]  # [died_received, killer_id]
	hp.died.connect(func(id: int) -> void:
		result[0] = true
		result[1] = id
	)
	# 4 hits of 25 = 100 damage = death
	hp.take_damage(25, 1)
	hp.take_damage(25, 1)
	hp.take_damage(25, 1)
	hp.take_damage(25, 1)
	Assert.assert_eq(hp.current_hp, 0, "HP is 0 after 100 damage")
	Assert.assert_false(hp.is_alive(), "Player is dead at 0 HP")
	Assert.assert_true(result[0], "died signal emitted")
	Assert.assert_eq(result[1], 1, "Killer peer ID matches source")


func _test_health_no_damage_when_dead() -> void:
	var hp := Health.new()
	hp.take_damage(100, 1)
	Assert.assert_eq(hp.current_hp, 0, "HP is 0")
	hp.take_damage(25, 2)
	Assert.assert_eq(hp.current_hp, 0, "HP stays at 0 when already dead")


func _test_health_reset() -> void:
	var hp := Health.new()
	hp.take_damage(50, 1)
	hp.reset()
	Assert.assert_eq(hp.current_hp, 100, "HP resets to max")
	Assert.assert_true(hp.is_alive(), "Alive after reset")
