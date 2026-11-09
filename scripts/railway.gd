class_name Railway
extends Node3D
## The railway is a *chain*: every new piece is appended to the end of the
## current line, exactly like the original game. Pieces therefore carry a
## cumulative position, a cumulative heading and a cumulative distance.

signal changed
signal piece_committed(piece: TrackPiece)
signal piece_removed(piece: TrackPiece)
signal loop_completed

const PIECE_MESH_PARENT := "track_container"

var track_container: Node3D

var total_offset := TrackData.DEFAULT_TRACK_OFFSET
var total_rotation := 0.0
var total_distance := 0.0
var current_level := 0

var sequence: Array[TrackPiece] = []
var preview_piece: TrackPiece = null
var _preview_type := ""
## True once the line closes back onto the station; the train then runs forever.
var loop_closed := false


func _ready() -> void:
	track_container = Node3D.new()
	track_container.name = "TrackContainer"
	add_child(track_container)
	# The original game points the start of the line along world +X.
	track_container.rotation.y = PI * 0.5


func reset() -> void:
	for piece in sequence:
		piece.queue_free()
	sequence.clear()
	total_offset = TrackData.DEFAULT_TRACK_OFFSET
	total_rotation = 0.0
	total_distance = 0.0
	current_level = 0
	loop_closed = false
	cancel_preview()
	changed.emit()


## Creates a piece and places it at the end of the line without committing it.
func create_piece(type: String) -> TrackPiece:
	var piece := TrackPiece.create(type)
	if piece == null:
		return null
	piece.build_mesh()
	piece.position = total_offset
	piece.rotation.y = total_rotation
	track_container.add_child(piece)
	piece.force_update_transform()
	return piece


## The piece that would be added if the user clicked the given button right now.
func preview(type: String) -> void:
	if preview_piece != null and _preview_type == type:
		return
	cancel_preview()
	var piece := create_piece(type)
	preview_piece = piece
	_preview_type = type
	piece.is_preview = true
	piece.set_preview(problem_for(piece) == "")
	changed.emit()


func cancel_preview() -> void:
	if preview_piece != null:
		preview_piece.queue_free()
		preview_piece = null
	_preview_type = ""
	changed.emit()


## Adds the previewed piece to the line for real.
func commit_preview() -> bool:
	if preview_piece == null:
		return false
	var piece := preview_piece
	if problem_for(piece) != "":
		return false
	piece.is_preview = false
	preview_piece = null
	_preview_type = ""
	_commit(piece)
	return true


## Appends a piece directly (used when restoring a shared layout).
func add_and_commit(type: String) -> TrackPiece:
	var piece := create_piece(type)
	if piece == null:
		push_error("Railway: could not create piece '%s'" % type)
		return null
	_commit(piece)
	return piece


func _commit(piece: TrackPiece) -> void:
	var rotated := piece.offset.rotated(Vector3.UP, total_rotation)
	piece.set_meta("offset", rotated)
	piece.start_distance = total_distance
	sequence.append(piece)
	total_offset += rotated
	total_rotation += deg_to_rad(piece.angle_deg)
	total_distance += piece.distance
	current_level += piece.height_delta
	_add_lift_block(piece)
	changed.emit()
	piece_committed.emit(piece)
	_check_loop_closed(piece)


## The original game rings a bell when the line closes back on the station.
func _check_loop_closed(piece: TrackPiece) -> void:
	if sequence.size() < 3:
		return
	var first: TrackPiece = sequence[0]
	var start := first.world_position_at(0.0)
	var end := piece.world_position_at(piece.distance)
	if start.distance_to(end) < 0.002:
		loop_closed = true
		loop_completed.emit()


func remove_last_piece() -> void:
	if sequence.size() <= 1:
		return
	var piece: TrackPiece = sequence.pop_back()
	total_distance -= piece.distance
	total_rotation -= deg_to_rad(piece.angle_deg)
	total_offset -= piece.get_meta("offset", Vector3.ZERO)
	current_level -= piece.height_delta
	piece.queue_free()
	cancel_preview()
	changed.emit()
	piece_removed.emit(piece)


func remove_all_pieces() -> void:
	while sequence.size() > 1:
		remove_last_piece()
	cancel_preview()
	changed.emit()


## Restores a layout from a list of piece types (the station is implicit).
func load_layout(types: Array) -> void:
	reset()
	add_and_commit("station")
	for t in types:
		add_and_commit(String(t))


func layout() -> Array:
	var out: Array = []
	for piece in sequence:
		if piece.code >= 0:
			out.append(piece.type)
	return out


## The code sequence used for sharing links.
func layout_codes() -> Array:
	var out: Array = []
	for piece in sequence:
		if piece.code >= 0:
			out.append(piece.code)
	return out


# ---------------------------------------------------------------- validity --

## Returns an empty string when the piece may be placed, otherwise a short
## reason. Mirrors the original game's `_checkTrackPieceForProblem`.
func problem_for(piece: TrackPiece) -> String:
	if not TrackData.is_allowed_at_level(piece.type, current_level):
		return "This piece is not allowed at height level %d" % current_level
	if _is_out_of_bounds(piece):
		return "This piece is out of bounds"
	if _collides(piece):
		return "This piece would overlap the existing track"
	return ""


func _is_out_of_bounds(piece: TrackPiece) -> bool:
	var rotated := piece.offset.rotated(Vector3.UP, total_rotation)
	var end_point := total_offset + rotated
	var half := TrackData.TRACK_AREA_SIZE * 0.5
	if absf(end_point.x) > half or absf(end_point.z) > half:
		return true
	if end_point.y > TrackData.TRACK_AREA_HEIGHT or end_point.y < -0.01:
		return true
	return false


func _collides(piece: TrackPiece) -> bool:
	var new_boxes := piece.world_boxes()
	for other in sequence:
		var other_boxes := other.world_boxes()
		for i in range(new_boxes.size()):
			for j in range(other_boxes.size()):
				if _boxes_overlap(new_boxes[i], other_boxes[j]):
					return true
	return false


## Separating-axis test between two oriented boxes.
static func _boxes_overlap(a: Dictionary, b: Dictionary) -> bool:
	var axes_a: Array = a["axes"]
	var axes_b: Array = b["axes"]
	var half_a: Vector3 = a["half"]
	var half_b: Vector3 = b["half"]
	var center_a: Vector3 = a["center"]
	var center_b: Vector3 = b["center"]
	half_a = Vector3(absf(half_a.x), absf(half_a.y), absf(half_a.z))
	half_b = Vector3(absf(half_b.x), absf(half_b.y), absf(half_b.z))
	var ea := [half_a.x, half_a.y, half_a.z]
	var eb := [half_b.x, half_b.y, half_b.z]
	var t := center_b - center_a
	for i in range(3):
		for j in range(3):
			var r: float = axes_a[i].dot(axes_b[j])
			if absf(r) < 0.000001:
				continue
			var dist: float = absf(t.dot(axes_a[i]))
			var ra: float = ea[i]
			var rb: float = eb[0] * absf(axes_a[i].dot(axes_b[0])) \
				+ eb[1] * absf(axes_a[i].dot(axes_b[1])) \
				+ eb[2] * absf(axes_a[i].dot(axes_b[2]))
			if dist > ra + rb:
				return false
	# Cross-product axes.
	for i in range(3):
		for j in range(3):
			var axis: Vector3 = axes_a[i].cross(axes_b[j])
			if axis.length_squared() < 0.000001:
				continue
			axis = axis.normalized()
			var dist: float = absf(t.dot(axis))
			var ra := 0.0
			for k in range(3):
				if k != i:
					ra += ea[k] * absf(axis.dot(axes_a[k]))
			var rb := 0.0
			for k in range(3):
				if k != j:
					rb += eb[k] * absf(axis.dot(axes_b[k]))
			if dist > ra + rb:
				return false
	return true


# ------------------------------------------------------------------ train --

## World position and tangent of the train at `distance` along the line.
func sample_track(distance: float) -> Dictionary:
	if sequence.is_empty():
		return {}
	var d := distance
	# The train only wraps around when the line is a closed loop; on an open
	# line it drives to the end and stops there.
	if loop_closed:
		d = fposmod(distance, total_distance)
	for piece in sequence:
		var start: float = piece.start_distance
		var end: float = start + piece.distance
		if d >= start and d <= end:
			var local := d - start
			var s := piece.sample(local)
			var basis := piece.global_transform.basis
			var origin := piece.global_transform.origin
			var tangent: Vector3 = (basis * s["tangent"]).normalized()
			# Keep the up vector perpendicular to the tangent so that the train
			# tilts with the ramp pieces.
			var up: Vector3 = (Vector3.UP - tangent * Vector3.UP.dot(tangent)).normalized()
			return {
				"position": basis * s["position"] + origin,
				"tangent": tangent,
				"up": up,
			}
	return {}


# --------------------------------------------------------------- lift block --

func _add_lift_block(piece: TrackPiece) -> void:
	if piece.height_delta == 0:
		return
	var level := current_level
	if level <= 0:
		return
	var packed: PackedScene = load("res://assets/models/tracks/LIFTER_PIPES.glb")
	if packed == null:
		return
	var node := packed.instantiate()
	node.scale = Vector3(1.0, TrackData.LEVEL_HEIGHT * float(level), 1.0)
	node.position = Vector3(0.0, -TrackData.LEVEL_HEIGHT * float(level) - TrackData.PIECE_THICKNESS, 0.0)
	piece.add_child(node)
