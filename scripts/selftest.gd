class_name SelfTest
extends RefCounted
## Small self-check for the core mechanics. Run the game with `--selftest`.

static var failures := 0
static var checks := 0


static func _check(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  PASS  %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])


static func run(railway: Railway, train: Train) -> void:
	print("=== Choo-Choo World self test ===")
	_test_url()
	_test_chain(railway)
	_test_loop(railway)
	_test_overlap()
	_test_train(railway, train)
	print("=== %d checks, %d failures ===" % [checks, failures])


## Scenery that the track runs through has to disappear, like in the original.
static func test_scenery(game: Node) -> void:
	print("=== scenery ===")
	checks = 0
	failures = 0
	var landscape: Landscape = game.landscape
	_check("the diorama has scenery", landscape.props.size() > 0,
		str(landscape.props.size()))
	if landscape.props.is_empty():
		return
	var prop: Dictionary = landscape.props[0]
	prop["node"].visible = true
	var centre: Vector3 = prop["center"]
	# Build a piece right on top of the scenery.
	var piece: TrackPiece = game.railway.create_piece("straight_2")
	piece.position = Vector3(centre.x, 0.0, centre.z)
	piece.force_update_transform()
	landscape.on_track_piece_added(piece)
	_check("scenery under the track is hidden", not prop["node"].visible)
	landscape.on_track_piece_removed(piece, [])
	_check("scenery comes back when the track is removed", prop["node"].visible)
	piece.queue_free()
	print("=== %d checks, %d failures ===" % [checks, failures])


## Exercises the editor workflow through the same handlers the buttons use.
static func test_ui(game: Node) -> void:
	print("=== editor workflow ===")
	checks = 0
	failures = 0
	game.railway.load_layout([])
	var before: int = game.railway.sequence.size()
	game._on_piece_hovered("straight_1")
	_check("hovering a piece previews it", game.railway.preview_piece != null)
	game._on_piece_clicked("straight_1")
	_check("clicking commits the piece",
		game.railway.sequence.size() == before + 1 and game.railway.preview_piece == null,
		str(game.railway.sequence.size()))
	game._on_piece_hovered("left_0")
	game._on_piece_clicked("left_0")
	_check("a second piece can be added", game.railway.sequence.size() == before + 2)
	_check("the share code follows the layout",
		game.url.track_code == UrlManager.encode(game.railway.layout_codes()),
		game.url.track_code)
	game._on_piece_unhovered()
	_check("leaving a button cancels the preview", game.railway.preview_piece == null)
	game._on_undo()
	_check("undo removes the last piece", game.railway.sequence.size() == before + 1)
	var tint_before: Color = game.railway.sequence[1]._tint
	game._on_palette(2)
	_check("changing the palette recolours the track",
		game.railway.sequence[1]._tint != tint_before, str(game.railway.sequence[1]._tint))
	game._on_palette(0)
	game._on_delete_all()
	_check("delete all leaves only the station", game.railway.sequence.size() == 1)
	game._on_play_pause()
	_check("the play button starts the train", game.train.is_playing)
	game._on_play_pause()
	_check("the play button stops the train", not game.train.is_playing)
	game._on_reset()
	_check("reset puts the train back at the station", game.train.progress == 0.0)
	print("=== %d checks, %d failures ===" % [checks, failures])


static func _test_url() -> void:
	print("- share code")
	var codes := [3, 5, 5, 1, 7, 5, 8, 9, 1]
	var encoded := UrlManager.encode(codes)
	_check("default layout encodes to the web game's code", encoded == "DFFBHFIJB", encoded)
	var decoded := UrlManager.decode(encoded)
	_check("decode round trip", decoded == codes, str(decoded))
	var types: Array = []
	for c in decoded:
		types.append(TrackData.CODE_TO_TYPE.get(c, "?"))
	_check("codes map to piece types",
		types == ["left_0", "right_0", "right_0", "straight_1", "special_0", "right_0",
			"upAndDown_0", "upAndDown_1", "straight_1"], str(types))


static func _test_chain(railway: Railway) -> void:
	print("- track chain")
	railway.load_layout(["straight_0", "straight_1", "left_0", "right_0", "upAndDown_0",
		"upAndDown_1"])
	_check("station is the first piece", railway.sequence[0].type == "station")
	_check("seven pieces loaded", railway.sequence.size() == 7, str(railway.sequence.size()))
	var expected_distance := 0.48 + 0.06 + 0.12 + 0.188358 + 0.188358 + 0.253169 + 0.253169
	_check("total distance", absf(railway.total_distance - expected_distance) < 0.0005,
		"%.5f vs %.5f" % [railway.total_distance, expected_distance])
	_check("height level returns to zero", railway.current_level == 0, str(railway.current_level))
	var second: TrackPiece = railway.sequence[1]
	var station_end: Vector3 = railway.sequence[0].world_position_at(railway.sequence[0].distance)
	_check("second piece starts where the station ends",
		second.global_transform.origin.distance_to(station_end) < 0.02,
		str(second.global_transform.origin))
	# A straight piece that continues the line must be accepted.
	var continuation := railway.create_piece("straight_0")
	_check("a valid continuation is accepted", railway.problem_for(continuation) == "",
		railway.problem_for(continuation))
	railway.cancel_preview()


static func _test_loop(railway: Railway) -> void:
	print("- closing the loop")
	# A rounded rectangle: the station forms one side, four medium curves form
	# the corners and the remaining straights the other three sides.
	railway.load_layout(["left_1", "straight_1", "left_1", "straight_2", "straight_2",
		"left_1", "straight_1", "left_1"])
	_check("the line closes back on the station", railway.loop_closed,
		"end=%s" % str(railway.total_offset))
	_check("the loop ends at the station's start",
		railway.total_offset.distance_to(Vector3(0.0, 0.0, -0.2)) < 0.002,
		str(railway.total_offset))
	_check("the loop is closed", railway.loop_closed)


static func _test_overlap() -> void:
	print("- overlap test")
	var a := {
		"center": Vector3.ZERO,
		"axes": [Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		"half": Vector3(0.1, 0.1, 0.1),
	}
	var b := {
		"center": Vector3(0.05, 0.0, 0.0),
		"axes": [Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		"half": Vector3(0.1, 0.1, 0.1),
	}
	var c := {
		"center": Vector3(5.0, 0.0, 0.0),
		"axes": [Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		"half": Vector3(0.1, 0.1, 0.1),
	}
	_check("overlapping boxes are detected", Railway._boxes_overlap(a, b))
	_check("distant boxes do not overlap", not Railway._boxes_overlap(a, c))


static func _test_train(railway: Railway, train: Train) -> void:
	print("- train")
	railway.load_layout(["straight_1", "straight_1", "straight_1", "straight_1"])
	train.reset_to_start()
	var before: Vector3 = train.cab_transform().origin
	train.play()
	for i in range(60):
		train.update(1.0 / 60.0)
	var after: Vector3 = train.cab_transform().origin
	_check("the locomotive moves", before.distance_to(after) > 0.001,
		"%s -> %s" % [str(before), str(after)])
	var on_track: Dictionary = railway.sample_track(train.progress + train.cars[-1]["base"])
	_check("the locomotive stays on the track", not on_track.is_empty()
		and after.distance_to(on_track["position"]) < 0.05,
		str(after.distance_to(on_track.get("position", Vector3.ZERO))) if not on_track.is_empty() else "no sample")
	_check("speed builds up", train.speed > 0.05, "%.3f" % train.speed)
	train.pause()
	for i in range(30):
		train.update(1.0 / 60.0)
	var stopped: Vector3 = train.cab_transform().origin
	_check("the locomotive stops when paused", stopped.distance_to(after) < 0.05)
	# On an open line the train has to stop at the end instead of looping.
	railway.load_layout(["straight_1", "straight_1", "straight_1", "straight_1"])
	train.reset_to_start()
	train.play()
	for i in range(600):
		train.update(1.0 / 60.0)
	_check("the train stops at the end of an open line", train.reached_end,
		"progress=%.3f of %.3f" % [train.progress, railway.total_distance])
	# On a closed loop it keeps going.
	railway.load_layout(["left_1", "straight_1", "left_1", "straight_2", "straight_2",
		"left_1", "straight_1", "left_1"])
	train.reset_to_start()
	train.play()
	for i in range(1500):
		train.update(1.0 / 60.0)
	_check("the train keeps going round a closed loop", not train.reached_end
		and train.progress > railway.total_distance,
		"progress=%.3f of %.3f reached_end=%s" % [train.progress, railway.total_distance, str(train.reached_end)])
