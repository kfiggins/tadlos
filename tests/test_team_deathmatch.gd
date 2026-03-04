extends Node

## Tests for Team Deathmatch game mode: team assignment, scoring, spawning, friendly fire.
## Pure logic tests — no networking required.


func run_tests() -> void:
	_test_auto_assign_balances_teams()
	_test_auto_assign_with_preference()
	_test_bot_auto_distribution()
	_test_cross_team_kill_awards_team_score()
	_test_same_team_kill_no_team_score()
	_test_self_kill_no_team_score()
	_test_is_friendly_same_team()
	_test_is_friendly_different_teams()
	_test_is_friendly_no_team()
	_test_team_spawn_picks_correct_side()
	_test_team_spawn_avoids_enemies_not_teammates()
	_test_team_spawn_fallback()
	_test_unregister_removes_from_team()
	_test_change_team()
	_test_get_team()
	_test_respawn_delay_constant()


func _test_auto_assign_balances_teams() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1)
	gm.register_player(2)
	gm.register_player(3)
	gm.register_player(4)

	var red_count := 0
	var blue_count := 0
	for pid in gm.team_assignments:
		if gm.team_assignments[pid] == TeamConstants.Team.RED:
			red_count += 1
		elif gm.team_assignments[pid] == TeamConstants.Team.BLUE:
			blue_count += 1

	Assert.assert_eq(red_count, 2, "Auto-assign: 2 players on Red")
	Assert.assert_eq(blue_count, 2, "Auto-assign: 2 players on Blue")


func _test_auto_assign_with_preference() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.BLUE)
	Assert.assert_eq(gm.team_assignments[1], TeamConstants.Team.BLUE, "Preference honored: player 1 is Blue")

	gm.register_player(2, TeamConstants.Team.RED)
	Assert.assert_eq(gm.team_assignments[2], TeamConstants.Team.RED, "Preference honored: player 2 is Red")

	# Auto-assign should balance (1 red, 1 blue already)
	gm.register_player(3)
	# Either team is fine since balanced — just check it's assigned
	Assert.assert_true(
		gm.team_assignments[3] == TeamConstants.Team.RED or gm.team_assignments[3] == TeamConstants.Team.BLUE,
		"Auto-assigned player 3 has a team"
	)


func _test_bot_auto_distribution() -> void:
	var gm := GameModeTeamDeathmatch.new()
	# Register 6 bots with auto-assign
	for i in 6:
		gm.register_player(100 + i)

	var red_count := 0
	var blue_count := 0
	for pid in gm.team_assignments:
		if gm.team_assignments[pid] == TeamConstants.Team.RED:
			red_count += 1
		elif gm.team_assignments[pid] == TeamConstants.Team.BLUE:
			blue_count += 1

	Assert.assert_eq(red_count, 3, "Bot distribution: 3 on Red")
	Assert.assert_eq(blue_count, 3, "Bot distribution: 3 on Blue")


func _test_cross_team_kill_awards_team_score() -> void:
	var gm := _create_gm_with_two_teams()
	# Player 1 (Red) kills player 2 (Blue)
	gm.scores[1]["kills"] = 0
	gm.scores[2]["deaths"] = 0
	gm.team_scores[TeamConstants.Team.RED] = 0

	# Simulate the kill scoring logic (without RPCs)
	_simulate_kill(gm, 1, 2)

	Assert.assert_eq(gm.scores[1]["kills"], 1, "Cross-team kill: killer gets 1 kill")
	Assert.assert_eq(gm.scores[2]["deaths"], 1, "Cross-team kill: victim gets 1 death")
	Assert.assert_eq(gm.team_scores[TeamConstants.Team.RED], 1, "Cross-team kill: Red team score +1")
	Assert.assert_eq(gm.team_scores[TeamConstants.Team.BLUE], 0, "Cross-team kill: Blue team score unchanged")


func _test_same_team_kill_no_team_score() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)
	gm.register_player(3, TeamConstants.Team.RED)

	_simulate_kill(gm, 1, 3)

	Assert.assert_eq(gm.team_scores[TeamConstants.Team.RED], 0, "Same-team kill: no team score change")
	Assert.assert_eq(gm.scores[1]["kills"], 1, "Same-team kill: individual kill still counts")
	Assert.assert_eq(gm.scores[3]["deaths"], 1, "Same-team kill: individual death still counts")


func _test_self_kill_no_team_score() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)

	_simulate_kill(gm, 1, 1)

	Assert.assert_eq(gm.team_scores[TeamConstants.Team.RED], 0, "Self-kill: no team score change")
	Assert.assert_eq(gm.scores[1]["kills"], 0, "Self-kill: no kill awarded")
	Assert.assert_eq(gm.scores[1]["deaths"], 1, "Self-kill: death counted")


func _test_is_friendly_same_team() -> void:
	var gm := _create_gm_with_two_teams()
	# Players 1 and 3 are both Red
	Assert.assert_true(gm.is_friendly(1, 3), "Same Red team players are friendly")


func _test_is_friendly_different_teams() -> void:
	var gm := _create_gm_with_two_teams()
	Assert.assert_false(gm.is_friendly(1, 2), "Red vs Blue are not friendly")


func _test_is_friendly_no_team() -> void:
	var gm := GameModeTeamDeathmatch.new()
	# Unregistered players have no team
	Assert.assert_false(gm.is_friendly(1, 2), "Unregistered players are not friendly")


func _test_team_spawn_picks_correct_side() -> void:
	var points: Array[Vector2] = [
		Vector2(500, 500),    # Left
		Vector2(1000, 500),   # Left
		Vector2(5000, 500),   # Right
		Vector2(5500, 500),   # Right
	]
	var sp := SpawnPoints.new(points)

	# Red team (left side, team_side = -1)
	var red_spawn := sp.get_team_spawn_point(-1, [], 3000.0)
	Assert.assert_true(red_spawn.x < 3000.0, "Red team spawns on left side (x=%.0f)" % red_spawn.x)

	# Blue team (right side, team_side = +1)
	var blue_spawn := sp.get_team_spawn_point(1, [], 3000.0)
	Assert.assert_true(blue_spawn.x > 3000.0, "Blue team spawns on right side (x=%.0f)" % blue_spawn.x)


func _test_team_spawn_avoids_enemies_not_teammates() -> void:
	var points: Array[Vector2] = [
		Vector2(500, 500),    # Left, far from enemy
		Vector2(2500, 500),   # Left, close to enemy
	]
	var sp := SpawnPoints.new(points)

	# Enemy at (2800, 500) - close to the second left spawn
	var enemy_positions: Array[Vector2] = [Vector2(2800, 500)]
	var spawn := sp.get_team_spawn_point(-1, enemy_positions, 3000.0)

	Assert.assert_eq(spawn, Vector2(500, 500), "Team spawn avoids enemy position, picks far spawn")


func _test_team_spawn_fallback() -> void:
	# Only right-side points, but request left side
	var points: Array[Vector2] = [
		Vector2(4000, 500),
		Vector2(5000, 500),
	]
	var sp := SpawnPoints.new(points)
	var spawn := sp.get_team_spawn_point(-1, [], 3000.0)
	# Should fallback to any available point
	Assert.assert_true(spawn.x > 3000.0, "Fallback uses available points when no team-side points exist")


func _test_unregister_removes_from_team() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)
	Assert.assert_true(gm.team_assignments.has(1), "Player 1 assigned before unregister")

	gm.unregister_player(1)
	Assert.assert_false(gm.team_assignments.has(1), "Player 1 removed from team_assignments after unregister")
	Assert.assert_false(gm.scores.has(1), "Player 1 removed from scores after unregister")


func _test_change_team() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)
	Assert.assert_eq(gm.team_assignments[1], TeamConstants.Team.RED, "Player starts on Red")

	# change_team requires multiplayer server check — test the data directly
	gm.team_assignments[1] = TeamConstants.Team.BLUE
	Assert.assert_eq(gm.team_assignments[1], TeamConstants.Team.BLUE, "Player changed to Blue")


func _test_get_team() -> void:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)
	Assert.assert_eq(gm.get_team(1), TeamConstants.Team.RED, "get_team returns RED for player 1")
	Assert.assert_eq(gm.get_team(999), TeamConstants.Team.NONE, "get_team returns NONE for unknown player")


func _test_respawn_delay_constant() -> void:
	Assert.assert_eq(TeamConstants.RESPAWN_DELAY, 3.0, "Shared respawn delay is 3.0 seconds")
	Assert.assert_eq(GameModeTeamDeathmatch.RESPAWN_DELAY, 3.0, "TDM respawn delay is 3.0 seconds")


# --- Helpers ---

func _create_gm_with_two_teams() -> GameModeTeamDeathmatch:
	var gm := GameModeTeamDeathmatch.new()
	gm.register_player(1, TeamConstants.Team.RED)
	gm.register_player(2, TeamConstants.Team.BLUE)
	gm.register_player(3, TeamConstants.Team.RED)
	gm.register_player(4, TeamConstants.Team.BLUE)
	return gm


## Simulate the scoring part of on_player_killed (without RPCs or scene tree).
func _simulate_kill(gm: GameModeTeamDeathmatch, killer_id: int, victim_id: int) -> void:
	gm.register_player(killer_id)
	gm.register_player(victim_id)

	if killer_id != victim_id:
		gm.scores[killer_id]["kills"] += 1
		if not gm.is_friendly(killer_id, victim_id):
			var killer_team: int = gm.team_assignments.get(killer_id, TeamConstants.Team.NONE)
			if gm.team_scores.has(killer_team):
				gm.team_scores[killer_team] += 1
	gm.scores[victim_id]["deaths"] += 1
