class_name StateSnapshot

## Data class for network state snapshots.
## Provides conversion to/from Dictionary for RPC serialization.

var peer_id: int = 0
var tick: int = 0
var last_input_seq: int = 0
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var grounded: bool = false
var fuel: float = 0.0
var aim_angle: float = 0.0


static func from_dict(data: Dictionary) -> StateSnapshot:
	var snap := StateSnapshot.new()
	snap.peer_id = data.get("peer_id", 0)
	snap.tick = data.get("tick", 0)
	snap.last_input_seq = data.get("last_input_seq", 0)
	snap.position = Vector2(data.get("position_x", 0.0), data.get("position_y", 0.0))
	snap.velocity = Vector2(data.get("velocity_x", 0.0), data.get("velocity_y", 0.0))
	snap.grounded = data.get("grounded", false)
	snap.fuel = data.get("fuel", 0.0)
	snap.aim_angle = data.get("aim_angle", 0.0)
	return snap


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"tick": tick,
		"last_input_seq": last_input_seq,
		"position_x": position.x,
		"position_y": position.y,
		"velocity_x": velocity.x,
		"velocity_y": velocity.y,
		"grounded": grounded,
		"fuel": fuel,
		"aim_angle": aim_angle,
	}
