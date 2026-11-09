class_name TrackData
## Static catalogue of the track pieces, mirroring the original game's
## `trackData.trackPieces` table (choochooworld.com/index.*.js).
##
## Every piece is a chunk of wooden railway that gets appended to the end of
## the current line. `angle` is how much the line turns *after* the piece,
## `height_delta` how many levels it climbs (+1) or descends (-1), and
## `level_only` restricts where the piece may be used (-1 = anywhere).

const TRACK_AREA_SIZE := 3.0
const TRACK_AREA_HEIGHT := 0.6
const DEFAULT_TRACK_OFFSET := Vector3(0.0, 0.0, -0.2)
const LEVEL_HEIGHT := 0.07
const PIECE_THICKNESS := 0.012

## code -> definition. The code is what ends up in the shared URL.
const PIECES := {
	"station": {
		"code": -1,
		"spline": "station",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": 0,
		"model": "res://assets/models/tracks/STATION.glb",
		"texture": "res://assets/textures/tracks/station/lowres/station_diffuse_day.jpg",
		"icon": "",
		"name": "Station",
	},
	"straight_0": {
		"code": 0,
		"spline": "straight_0",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/STRAIGHT_0.glb",
		"texture": "res://assets/textures/tracks/straight/straight_0/lowres/straight_0_ao.jpg",
		"icon": "res://assets/images/tracks/straight/straight-s.png",
		"name": "Straight (short)",
	},
	"straight_1": {
		"code": 1,
		"spline": "straight_1",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/STRAIGHT_1.glb",
		"texture": "res://assets/textures/tracks/straight/straight_1/lowres/straight_1_ao.jpg",
		"icon": "res://assets/images/tracks/straight/straight-m.png",
		"name": "Straight (medium)",
	},
	"straight_2": {
		"code": 2,
		"spline": "straight_2",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/STRAIGHT_2.glb",
		"texture": "res://assets/textures/tracks/straight/straight_2/lowres/straight_2_ao.jpg",
		"icon": "res://assets/images/tracks/straight/straight-l.png",
		"name": "Straight (long)",
	},
	"left_0": {
		"code": 3,
		"spline": "left_0",
		"angle": 90.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/LEFT_0.glb",
		"texture": "res://assets/textures/tracks/left/left_0/lowres/left_0_ao.jpg",
		"icon": "res://assets/images/tracks/left/left-s.png",
		"name": "Left curve (small)",
	},
	"left_1": {
		"code": 4,
		"spline": "left_1",
		"angle": 90.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/LEFT_1.glb",
		"texture": "res://assets/textures/tracks/left/left_1/lowres/left_1_ao.jpg",
		"icon": "res://assets/images/tracks/left/left-m.png",
		"name": "Left curve (medium)",
	},
	"right_0": {
		"code": 5,
		"spline": "right_0",
		"angle": -90.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/RIGHT_0.glb",
		"texture": "res://assets/textures/tracks/right/right_0/lowres/right_0_ao.jpg",
		"icon": "res://assets/images/tracks/right/right-s.png",
		"name": "Right curve (small)",
	},
	"right_1": {
		"code": 6,
		"spline": "right_1",
		"angle": -90.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/RIGHT_1.glb",
		"texture": "res://assets/textures/tracks/right/right_1/lowres/right_1_ao.jpg",
		"icon": "res://assets/images/tracks/right/right-m.png",
		"name": "Right curve (medium)",
	},
	"special_0": {
		"code": 7,
		"spline": "tunnel",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": 0,
		"model": "res://assets/models/tracks/TUNNEL.glb",
		"texture": "res://assets/textures/tracks/tunnel/lowres/tunnel_diffuse.jpg",
		"icon": "res://assets/images/tracks/special/tunnel/tunnel.png",
		"name": "Tunnel",
	},
	"upAndDown_0": {
		"code": 8,
		"spline": "up",
		"angle": 0.0,
		"height_delta": 1,
		"level_only": -1,
		"model": "res://assets/models/tracks/UP.glb",
		"texture": "res://assets/textures/tracks/up/lowres/up_ao.jpg",
		"icon": "res://assets/images/tracks/upAndDown/up/up.png",
		"name": "Ramp up",
	},
	"upAndDown_1": {
		"code": 9,
		"spline": "down",
		"angle": 0.0,
		"height_delta": -1,
		"level_only": -1,
		"model": "res://assets/models/tracks/DOWN.glb",
		"texture": "res://assets/textures/tracks/down/lowres/down_ao.jpg",
		"icon": "res://assets/images/tracks/upAndDown/down/down.png",
		"name": "Ramp down",
	},
	"special_2": {
		"code": 10,
		"spline": "roll_right",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": -1,
		"model": "res://assets/models/tracks/ROLL_RIGHT.glb",
		"texture": "res://assets/textures/tracks/roll/lowres/roll_ao.jpg",
		"icon": "res://assets/images/tracks/special/loop/loop_00000.png",
		"name": "Crossover loop",
	},
	"special_1": {
		"code": 11,
		"spline": "barriage",
		"angle": 0.0,
		"height_delta": 0,
		"level_only": 0,
		"model": "res://assets/models/tracks/BARRIAGE.glb",
		"texture": "res://assets/textures/tracks/barriage/lowres/barriage_diffuse.jpg",
		"icon": "res://assets/images/tracks/special/passing/passing_00000.png",
		"name": "Passing loop",
	},
}

## code -> type name, for decoding shared links.
const CODE_TO_TYPE := {
	0: "straight_0",
	1: "straight_1",
	2: "straight_2",
	3: "left_0",
	4: "left_1",
	5: "right_0",
	6: "right_1",
	7: "special_0",
	8: "upAndDown_0",
	9: "upAndDown_1",
	10: "special_2",
	11: "special_1",
}

## The five colour palettes offered by the original game.
const COLOR_PALETTES := [
	["#ef4a4a", "#6e62ea", "#45d5ef", "#ffd857"],
	["#ff7ac8", "#f4b2f1", "#ef5172", "#7858f4"],
	["#74cff7", "#00b1d8", "#00ffdf", "#0093ff"],
	["#89653f", "#543c19", "#8e671e", "#f7be79"],
	["#00ea5d", "#20ffc9", "#34f97f", "#026d33"],
]

## Order the track editor shows the pieces in (matching the original menu).
const EDITOR_ORDER := [
	"special_1",
	"special_2",
	"special_0",
	"upAndDown_0",
	"upAndDown_1",
	"right_1",
	"right_0",
	"left_1",
	"left_0",
	"straight_2",
	"straight_1",
	"straight_0",
]

static func get_piece(type: String) -> Dictionary:
	return PIECES[type]

static func is_allowed_at_level(type: String, level: int) -> bool:
	var d: Dictionary = PIECES[type]
	var only: int = d["level_only"]
	return only < 0 or only == level
