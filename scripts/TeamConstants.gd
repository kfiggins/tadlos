class_name TeamConstants
extends RefCounted

## Shared constants for team-based game modes.

enum Team { NONE = 0, RED = 1, BLUE = 2 }
enum GameMode { FFA = 0, TEAM_DEATHMATCH = 1 }

const MAP_MIDPOINT_X: float = 3000.0

const RESPAWN_DELAY := 3.0

# Team shirt (body) colors for pixel-level coloring
const RED_BODY_COLOR := Color(0.8, 0.2, 0.2)
const BLUE_BODY_COLOR := Color(0.2, 0.4, 0.8)
const DEFAULT_BODY_COLOR := Color(0.2, 0.4, 0.8)  # FFA default (blue)

# Team leg colors
const RED_LEG_COLOR := Color(0.5, 0.15, 0.15)
const BLUE_LEG_COLOR := Color(0.15, 0.25, 0.5)
const DEFAULT_LEG_COLOR := Color(0.15, 0.25, 0.5)  # FFA default


static func get_team_body_color(team: int) -> Color:
	match team:
		Team.RED:
			return RED_BODY_COLOR
		Team.BLUE:
			return BLUE_BODY_COLOR
		_:
			return DEFAULT_BODY_COLOR


static func get_team_leg_color(team: int) -> Color:
	match team:
		Team.RED:
			return RED_LEG_COLOR
		Team.BLUE:
			return BLUE_LEG_COLOR
		_:
			return DEFAULT_LEG_COLOR


static func get_team_name(team: int) -> String:
	match team:
		Team.RED:
			return "Red"
		Team.BLUE:
			return "Blue"
		_:
			return ""


# FFA player colors (8 distinct shirt + leg pairs for up to 8 players)
const FFA_BODY_COLORS: Array = [
	Color(0.2, 0.7, 0.3),   # Green
	Color(0.9, 0.5, 0.1),   # Orange
	Color(0.6, 0.2, 0.8),   # Purple
	Color(0.1, 0.7, 0.8),   # Cyan
	Color(0.9, 0.8, 0.1),   # Yellow
	Color(0.9, 0.3, 0.6),   # Pink
	Color(0.8, 0.8, 0.8),   # White/Gray
	Color(0.6, 0.35, 0.15), # Brown
]

const FFA_LEG_COLORS: Array = [
	Color(0.15, 0.4, 0.2),  # Dark green
	Color(0.5, 0.3, 0.1),   # Dark orange
	Color(0.35, 0.15, 0.45),# Dark purple
	Color(0.1, 0.4, 0.45),  # Dark cyan
	Color(0.5, 0.45, 0.1),  # Dark yellow
	Color(0.5, 0.2, 0.35),  # Dark pink
	Color(0.45, 0.45, 0.45),# Dark gray
	Color(0.35, 0.2, 0.1),  # Dark brown
]


static func get_ffa_body_color(index: int) -> Color:
	return FFA_BODY_COLORS[index % FFA_BODY_COLORS.size()]


static func get_ffa_leg_color(index: int) -> Color:
	return FFA_LEG_COLORS[index % FFA_LEG_COLORS.size()]


## Returns -1 for Red (left side), +1 for Blue (right side), 0 for no team.
static func get_team_side(team: int) -> int:
	match team:
		Team.RED:
			return -1
		Team.BLUE:
			return 1
		_:
			return 0
