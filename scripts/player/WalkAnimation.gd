class_name WalkAnimation
extends RefCounted

## Pure-logic walk animation controller.
## Generates 3 sprite frame textures (idle + 2 walk) and cycles between them
## based on horizontal velocity and grounded state.

const WALK_SPEED_THRESHOLD := 20.0
const FRAME_DURATION := 0.15

const FRAME_IDLE := 0
const FRAME_WALK_A := 1
const FRAME_WALK_B := 2

var _frames: Array = []
var _current_frame: int = FRAME_IDLE
var _frame_timer: float = 0.0


## Generate 3 sprite frame textures with the given body/leg colors.
## Returns Array of 3 ImageTexture (idle, walk_a, walk_b).
static func generate_frames(
	body_color: Color = Color(0.2, 0.4, 0.8),
	leg_color: Color = Color(0.15, 0.25, 0.5),
) -> Array:
	# Leg X ranges per frame: [left_start, left_end, right_start, right_end]
	var leg_positions := [
		[5, 11, 13, 19],   # Idle: centered
		[3, 9, 15, 21],    # Walk A: spread (shifted 2px outward)
		[8, 14, 10, 16],   # Walk B: close (shifted 3px inward)
	]

	var textures: Array = []
	for frame_i in 3:
		var img := Image.create(24, 48, false, Image.FORMAT_RGBA8)
		# Head (skin tone)
		for y in range(0, 12):
			for x in range(6, 18):
				img.set_pixel(x, y, Color(0.9, 0.75, 0.6))
		# Body
		for y in range(12, 32):
			for x in range(4, 20):
				img.set_pixel(x, y, body_color)
		# Legs
		var lp: Array = leg_positions[frame_i]
		for y in range(32, 48):
			for x in range(lp[0], mini(lp[1], 24)):
				img.set_pixel(x, y, leg_color)
			for x in range(maxi(lp[2], 0), mini(lp[3], 24)):
				img.set_pixel(x, y, leg_color)
		textures.append(ImageTexture.create_from_image(img))

	return textures


func set_frames(frames: Array) -> void:
	_frames = frames
	_current_frame = FRAME_IDLE
	_frame_timer = 0.0


## Update animation state. Returns new ImageTexture when frame changes, null otherwise.
func update(velocity_x: float, grounded: bool, delta: float) -> ImageTexture:
	if _frames.is_empty():
		return null

	var should_walk := absf(velocity_x) > WALK_SPEED_THRESHOLD and grounded

	if not should_walk:
		if _current_frame != FRAME_IDLE:
			_current_frame = FRAME_IDLE
			_frame_timer = 0.0
			return _frames[FRAME_IDLE]
		return null

	# Walking: advance timer and cycle A <-> B
	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_frame_timer = FRAME_DURATION
		if _current_frame == FRAME_WALK_A:
			_current_frame = FRAME_WALK_B
		else:
			_current_frame = FRAME_WALK_A
		return _frames[_current_frame]

	return null


func get_idle_frame() -> ImageTexture:
	if _frames.is_empty():
		return null
	return _frames[FRAME_IDLE]


func get_current_frame() -> int:
	return _current_frame
