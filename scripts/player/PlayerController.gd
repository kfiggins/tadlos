class_name PlayerController
extends CharacterBody2D

## Player controller — handles input sampling, movement simulation, and facing.
## Movement math is in calculate_velocity() so it can be reused by server/prediction.

var fuel: float = MovementTuning.JETPACK_MAX_FUEL
var aim_angle: float = 0.0
var _facing_right: bool = true
var _tick_accumulator: float = 0.0
var _walk_anim: WalkAnimation = WalkAnimation.new()

# Buffer edge-triggered inputs so they survive between tick boundaries.
# is_action_just_pressed fires for one frame, but the 30Hz tick loop may
# not run that frame — buffering prevents lost jumps/dives.
var _jump_buffered: bool = false
var _dive_buffered: bool = false


func _ready() -> void:
	_create_placeholder_sprite()


func _physics_process(delta: float) -> void:
	# Buffer edge-triggered inputs before the tick loop
	if Input.is_action_just_pressed("jump"):
		_jump_buffered = true
	if Input.is_action_just_pressed("dive"):
		_dive_buffered = true

	# Use same fixed tick rate as NetworkedPlayer for consistent movement
	var tick_delta := 1.0 / NetConstants.TICK_RATE
	_tick_accumulator += delta
	while _tick_accumulator >= tick_delta:
		_tick_accumulator -= tick_delta

		var input := sample_input()
		# Merge buffered edge-triggers into the input
		if _jump_buffered:
			input.jump = true
		if _dive_buffered:
			input.dive = true
		var state := _build_state()
		var result := calculate_velocity(state, input, tick_delta)

		velocity = result.velocity
		fuel = result.fuel
		move_and_slide()
		_update_facing(input.aim_angle)
		# Clear buffers after the first tick consumes them
		_jump_buffered = false
		_dive_buffered = false

	# Walk animation
	var walk_tex := _walk_anim.update(velocity.x, is_on_floor(), delta)
	if walk_tex != null:
		$Sprite2D.texture = walk_tex

	# Push data to debug overlay
	Debug.set_overlay_data({
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	})


## Reads current input actions and mouse aim. Separated from simulation.
func sample_input() -> Dictionary:
	var input := sample_input_at(global_position, get_global_mouse_position())
	aim_angle = input.aim_angle
	return input


## Static input sampler usable by both local and networked player controllers.
static func sample_input_at(player_pos: Vector2, mouse_pos: Vector2) -> Dictionary:
	var move_dir := 0.0
	if Input.is_action_pressed("move_right"):
		move_dir += 1.0
	if Input.is_action_pressed("move_left"):
		move_dir -= 1.0

	return {
		"move_dir": move_dir,
		"jump": Input.is_action_just_pressed("jump"),
		"jetpack": Input.is_action_pressed("jetpack"),
		"dive": Input.is_action_just_pressed("dive"),
		"aim_angle": player_pos.angle_to_point(mouse_pos),
	}


## Build state dict from current player state.
func _build_state() -> Dictionary:
	return {
		"velocity": velocity,
		"grounded": is_on_floor(),
		"fuel": fuel,
	}


## Pure movement calculation. Given state + input + delta, returns new velocity and fuel.
## Collision resolution happens separately via move_and_slide().
static func calculate_velocity(state: Dictionary, input: Dictionary, delta: float) -> Dictionary:
	var vel: Vector2 = state.velocity
	var grounded: bool = state.grounded
	var cur_fuel: float = state.fuel

	var move_dir: float = input.move_dir
	var wants_jump: bool = input.jump
	var wants_jetpack: bool = input.jetpack
	var wants_dive: bool = input.dive

	# --- Horizontal movement ---
	var accel := MovementTuning.GROUND_ACCEL if grounded else MovementTuning.AIR_ACCEL
	if move_dir != 0.0:
		vel.x += move_dir * accel * delta
		vel.x = clampf(vel.x, -MovementTuning.MAX_SPEED, MovementTuning.MAX_SPEED)
	else:
		# Apply friction when no input
		var friction := MovementTuning.GROUND_FRICTION if grounded else MovementTuning.AIR_FRICTION
		vel.x *= friction

	# --- Gravity ---
	if not grounded:
		vel.y += MovementTuning.GRAVITY * delta

	# --- Jump ---
	if wants_jump and grounded:
		vel.y = MovementTuning.JUMP_VELOCITY

	# --- Jetpack ---
	if wants_jetpack and cur_fuel > 0.0:
		vel.y += MovementTuning.JETPACK_FORCE * delta
		cur_fuel -= MovementTuning.JETPACK_BURN_RATE * delta
		cur_fuel = maxf(cur_fuel, 0.0)
	elif not wants_jetpack:
		# Recharge fuel whenever not using jetpack
		cur_fuel += MovementTuning.JETPACK_RECHARGE_RATE * delta
		cur_fuel = minf(cur_fuel, MovementTuning.JETPACK_MAX_FUEL)

	# --- Dive / roll ---
	if wants_dive:
		if move_dir != 0.0:
			vel.x += move_dir * MovementTuning.DIVE_IMPULSE
		elif vel.x > 0.0:
			vel.x += MovementTuning.DIVE_IMPULSE
		else:
			vel.x -= MovementTuning.DIVE_IMPULSE

	return {
		"velocity": vel,
		"fuel": cur_fuel,
	}


func _update_facing(angle: float) -> void:
	# Aim angle from angle_to_point: 0 = right, PI/-PI = left
	# Mouse to the right of player means cos(angle) < 0 (angle_to_point convention)
	# Actually, angle_to_point gives angle FROM self TO target, so:
	#   mouse right of player → angle is between -PI/2 and PI/2
	var should_face_right := cos(angle) < 0.0
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		$Sprite2D.flip_h = not _facing_right


func _create_placeholder_sprite() -> void:
	var frames := WalkAnimation.generate_frames(Color(0.2, 0.4, 0.8), Color(0.15, 0.25, 0.5))
	_walk_anim.set_frames(frames)
	$Sprite2D.texture = _walk_anim.get_idle_frame()
