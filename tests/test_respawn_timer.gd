extends Node

## Tests death/respawn flow: Health death, weapon reset, dead state flag,
## and respawn restoring full state.
## Pure logic tests — no networking or physics required.

func run_tests() -> void:
	_test_health_death_sets_dead()
	_test_dead_player_cant_take_more_damage()
	_test_health_reset_revives()
	_test_weapon_reset_refills_ammo()
	_test_weapon_reset_clears_reload()
	_test_weapon_reset_clears_cooldown()
	_test_full_respawn_flow()
	_test_spawn_points_used_for_respawn()
	_test_respawn_delay_constant()


func _test_health_death_sets_dead() -> void:
	var hp := Health.new()
	var died_info := [false, -1]
	hp.died.connect(func(killer_id: int) -> void:
		died_info[0] = true
		died_info[1] = killer_id
	)
	hp.take_damage(100, 5)
	Assert.assert_false(hp.is_alive(), "Player is dead after 100 damage")
	Assert.assert_eq(hp.current_hp, 0, "HP is 0")
	Assert.assert_true(died_info[0], "died signal emitted")
	Assert.assert_eq(died_info[1], 5, "Killer ID is 5")


func _test_dead_player_cant_take_more_damage() -> void:
	var hp := Health.new()
	hp.take_damage(100, 1)
	var changed := [false]
	hp.health_changed.connect(func(_new_hp: int, _max_hp: int) -> void:
		changed[0] = true
	)
	hp.take_damage(50, 2)
	Assert.assert_eq(hp.current_hp, 0, "HP stays at 0")
	Assert.assert_false(changed[0], "No health_changed when already dead")


func _test_health_reset_revives() -> void:
	var hp := Health.new()
	hp.take_damage(100, 1)
	Assert.assert_false(hp.is_alive(), "Dead before reset")
	hp.reset()
	Assert.assert_true(hp.is_alive(), "Alive after reset")
	Assert.assert_eq(hp.current_hp, 100, "HP is max after reset")


func _test_weapon_reset_refills_ammo() -> void:
	var weapon := WeaponRifle.new()
	# Fire some shots
	for i in range(5):
		weapon.fire()
		weapon.process_cooldown(0.2)
	Assert.assert_eq(weapon.current_ammo, 25, "5 shots fired, 25 remaining")
	weapon.reset()
	Assert.assert_eq(weapon.current_ammo, 30, "Ammo refilled to max after reset")


func _test_weapon_reset_clears_reload() -> void:
	var config := WeaponConfig.new()
	config.max_ammo = 1
	config.reload_time = 2.0
	var weapon := WeaponRifle.new(config)
	weapon.fire()
	Assert.assert_true(weapon.reloading, "Reloading after last round")
	weapon.reset()
	Assert.assert_false(weapon.reloading, "Not reloading after reset")
	Assert.assert_eq(weapon.current_ammo, 1, "Ammo refilled after reset")
	Assert.assert_true(weapon.can_fire(), "Can fire after reset")


func _test_weapon_reset_clears_cooldown() -> void:
	var weapon := WeaponRifle.new()
	weapon.fire()
	Assert.assert_false(weapon.can_fire(), "Cooldown active after fire")
	weapon.reset()
	Assert.assert_true(weapon.can_fire(), "Can fire after reset (cooldown cleared)")


func _test_full_respawn_flow() -> void:
	# Simulate full death → reset → ready-to-fight flow
	var hp := Health.new()
	var weapon := WeaponRifle.new()

	# Fire some shots
	weapon.fire()
	weapon.process_cooldown(0.2)
	weapon.fire()

	# Take lethal damage
	hp.take_damage(100, 3)
	Assert.assert_false(hp.is_alive(), "Player dead")
	Assert.assert_false(weapon.can_fire(), "Can't fire (cooldown)")

	# Respawn: reset both
	hp.reset()
	weapon.reset()

	Assert.assert_true(hp.is_alive(), "Alive after respawn")
	Assert.assert_eq(hp.current_hp, 100, "Full HP after respawn")
	Assert.assert_true(weapon.can_fire(), "Can fire after respawn")
	Assert.assert_eq(weapon.current_ammo, 30, "Full ammo after respawn")


func _test_spawn_points_used_for_respawn() -> void:
	var points: Array[Vector2] = [
		Vector2(100, 200),
		Vector2(500, 200),
		Vector2(900, 200),
	]
	var sp := SpawnPoints.new(points)
	# Pick a point avoiding position near (100, 200)
	var avoid: Array[Vector2] = [Vector2(100, 200)]
	var result := sp.get_spawn_point(avoid)
	# Should pick farthest from (100, 200) — that's (900, 200)
	Assert.assert_eq(result, Vector2(900, 200), "Spawn point avoids nearby player")


func _test_respawn_delay_constant() -> void:
	# Verify the respawn delay matches spec (3.0 seconds)
	Assert.assert_eq(GameModeDeathmatch.RESPAWN_DELAY, 3.0, "Respawn delay is 3.0 seconds")
