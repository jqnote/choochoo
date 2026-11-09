class_name TrackPiece
extends Node3D
## One chunk of wooden railway.
##
## A piece owns the mesh that gets drawn plus the spline that the train
## follows through it. The spline data was extracted from the original game's
## `*_SPLINE.buf` files, so the geometry matches the web version exactly.

var type := ""
var code := -1
var angle_deg := 0.0
var height_delta := 0
var distance := 0.0
## Vector from the start of the piece to its end, in the piece's own space.
var offset := Vector3.ZERO
## Distance along the whole railway at which this piece starts.
var start_distance := 0.0

var positions: Array = []
var tangents: Array = []
var centers: Array = []
var half_sizes: Array = []
var orients: Array = []

var mesh_instance: MeshInstance3D
var is_preview := false
var _tint := Color.WHITE
var _preview_ok := true


static func create(p_type: String) -> TrackPiece:
	var piece := TrackPiece.new()
	piece.type = p_type
	var def: Dictionary = TrackData.get_piece(p_type)
	piece.code = def["code"]
	piece.angle_deg = def["angle"]
	piece.height_delta = def["height_delta"]
	var spline: Dictionary = SplineData.DATA[def["spline"]]
	piece.distance = spline["distance"]
	piece.positions = spline["positions"]
	piece.tangents = spline["tangents"]
	piece.centers = spline["centers"]
	piece.half_sizes = spline["half_sizes"]
	piece.orients = spline["orients"]
	piece.offset = piece.positions[piece.positions.size() - 1] - piece.positions[0]
	return piece


func build_mesh() -> void:
	var def: Dictionary = TrackData.get_piece(type)
	var packed: PackedScene = load(def["model"])
	if packed == null:
		push_error("TrackPiece: missing model %s" % def["model"])
		return
	var node := packed.instantiate()
	add_child(node)
	mesh_instance = _find_mesh(node)
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


## Rebuilds the material with the current tint (and preview colouring).
func apply_color() -> void:
	if mesh_instance == null:
		return
	var def: Dictionary = TrackData.get_piece(type)
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var tex_path: String = def["texture"]
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	if is_preview:
		mat.albedo_color = Color(0.15, 1.0, 0.25) if _preview_ok else Color(1.0, 0.15, 0.15)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.8
	else:
		mat.albedo_color = _tint
	mesh_instance.material_override = mat


func set_preview(valid: bool) -> void:
	_preview_ok = valid
	apply_color()


func set_tint(tint: Color) -> void:
	_tint = tint
	apply_color()


## Samples the piece's spline. Returns the local position and tangent at
## `local_distance` metres from the start of the piece.
func sample(local_distance: float) -> Dictionary:
	var n := positions.size()
	if n == 0:
		return {"position": Vector3.ZERO, "tangent": Vector3.BACK}
	if n == 1:
		return {"position": positions[0], "tangent": Vector3.BACK}
	var acc := 0.0
	for i in range(1, n):
		var seg: float = positions[i - 1].distance_to(positions[i])
		if local_distance <= acc + seg or i == n - 1:
			var t := 0.0
			if seg > 0.000001:
				t = clampf((local_distance - acc) / seg, 0.0, 1.0)
			return {
				"position": positions[i - 1].lerp(positions[i], t),
				"tangent": tangents[i - 1].lerp(tangents[i], t).normalized(),
			}
		acc += seg
	return {"position": positions[n - 1], "tangent": tangents[n - 1]}


## The oriented boxes of this piece, in world space, used for the
## piece-against-piece overlap test.
func world_boxes() -> Array:
	var out: Array = []
	var basis := global_transform.basis
	for i in range(centers.size()):
		var local_center: Vector3 = centers[i]
		var half: Vector3 = half_sizes[i]
		var q: Quaternion = orients[i]
		if q.length_squared() < 0.000001:
			# A few samples in the original data (the tunnel) carry a
			# degenerate orientation; fall back to the piece's own axes.
			q = Quaternion.IDENTITY
		var center: Vector3 = basis * local_center + global_transform.origin
		var ax: Vector3 = (basis * (q * Vector3.RIGHT)).normalized()
		var ay: Vector3 = (basis * (q * Vector3.UP)).normalized()
		var az: Vector3 = (basis * (q * Vector3.BACK)).normalized()
		out.append({
			"center": center,
			"axes": [ax, ay, az],
			"half": Vector3(absf(half.x), absf(half.y), absf(half.z)),
		})
	return out


## World space position of a point `d` metres along this piece.
func world_position_at(d: float) -> Vector3:
	var s := sample(d)
	return global_transform.basis * s["position"] + global_transform.origin
