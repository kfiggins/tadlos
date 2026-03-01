extends Node

## Tests scoring logic: kill increments, death increments, self-kill handling.
## Pure logic tests using SpawnPoints and score dictionary manipulation.

func run_tests() -> void:
	_test_register_player()
	_test_kill_increments_scores()
	_test_multiple_kills_accumulate()
	_test_self_kill_no_kill_credit()
	_test_unregister_player()
	_test_scores_consistent_after_many_kills()


func _test_register_player() -> void:
	var scores: Dictionary = {}
	_register(scores, 1)
	Assert.assert_true(scores.has(1), "Player 1 registered in scores")
	Assert.assert_eq(scores[1]["kills"], 0, "Initial kills is 0")
	Assert.assert_eq(scores[1]["deaths"], 0, "Initial deaths is 0")


func _test_kill_increments_scores() -> void:
	var scores: Dictionary = {}
	_register(scores, 1)
	_register(scores, 2)
	_apply_kill(scores, 1, 2)
	Assert.assert_eq(scores[1]["kills"], 1, "Killer gets +1 kill")
	Assert.assert_eq(scores[2]["deaths"], 1, "Victim gets +1 death")
	Assert.assert_eq(scores[1]["deaths"], 0, "Killer deaths unchanged")
	Assert.assert_eq(scores[2]["kills"], 0, "Victim kills unchanged")


func _test_multiple_kills_accumulate() -> void:
	var scores: Dictionary = {}
	_register(scores, 1)
	_register(scores, 2)
	_apply_kill(scores, 1, 2)
	_apply_kill(scores, 1, 2)
	_apply_kill(scores, 2, 1)
	Assert.assert_eq(scores[1]["kills"], 2, "Player 1 has 2 kills after killing twice")
	Assert.assert_eq(scores[1]["deaths"], 1, "Player 1 has 1 death")
	Assert.assert_eq(scores[2]["kills"], 1, "Player 2 has 1 kill")
	Assert.assert_eq(scores[2]["deaths"], 2, "Player 2 has 2 deaths")


func _test_self_kill_no_kill_credit() -> void:
	var scores: Dictionary = {}
	_register(scores, 1)
	_apply_kill(scores, 1, 1)
	Assert.assert_eq(scores[1]["kills"], 0, "Self-kill does not increment kills")
	Assert.assert_eq(scores[1]["deaths"], 1, "Self-kill still increments deaths")


func _test_unregister_player() -> void:
	var scores: Dictionary = {}
	_register(scores, 1)
	_register(scores, 2)
	scores.erase(2)
	Assert.assert_false(scores.has(2), "Player 2 removed from scores")
	Assert.assert_true(scores.has(1), "Player 1 still in scores")


func _test_scores_consistent_after_many_kills() -> void:
	var scores: Dictionary = {}
	for i in range(1, 5):
		_register(scores, i)
	# Simulate a series of kills
	_apply_kill(scores, 1, 2)
	_apply_kill(scores, 3, 4)
	_apply_kill(scores, 1, 3)
	_apply_kill(scores, 2, 1)
	_apply_kill(scores, 4, 2)
	# Total kills should equal total deaths
	var total_kills := 0
	var total_deaths := 0
	for peer_id in scores:
		total_kills += scores[peer_id]["kills"]
		total_deaths += scores[peer_id]["deaths"]
	Assert.assert_eq(total_kills, total_deaths, "Total kills equals total deaths")
	Assert.assert_eq(total_kills, 5, "5 kills occurred")


# --- Helpers mimicking GameModeDeathmatch scoring logic ---

func _register(scores: Dictionary, peer_id: int) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = {"kills": 0, "deaths": 0}


func _apply_kill(scores: Dictionary, killer_id: int, victim_id: int) -> void:
	_register(scores, killer_id)
	_register(scores, victim_id)
	if killer_id != victim_id:
		scores[killer_id]["kills"] += 1
	scores[victim_id]["deaths"] += 1
