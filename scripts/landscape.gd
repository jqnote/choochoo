class_name Landscape
extends Node3D
## Builds the little diorama the railway lives in: rolling green hills, trees,
## grass, flowers, rocks, water and a wandering hot air balloon.
##
## The placement data comes from the original game's `landscapeData.json`.

const GROUND_COLOR := Color(0.44, 0.78, 0.36)
const WATER_COLOR := Color(0.35, 0.68, 0.86)

var data: Dictionary = {}
var balloon: Node3D
var balloon_path: PackedVector3Array = PackedVector3Array()
var _balloon_t := 0.0
var _tree_scene: PackedScene
var _grass_scene: PackedScene
var _flower_scene: PackedScene
var _rock_scene: PackedScene
var _cloud_scene: PackedScene
## Scenery that has to disappear when a track piece is built on top of it.
var props: Array = []


func _ready() -> void:
	_load_data()
	_build_ground()
	_build_props()
	_build_balloon()


func _load_data() -> void:
	var path := "res://assets/data/landscapeData.json"
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			data = parsed


func _build_ground() -> void:
	_build_terrain()
	# A wide green disc that fades into the sky, plus a slightly raised
	# plateau where the railway is built.
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 26.0)
	disc.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	disc.material_override = mat
	disc.position = Vector3(0.0, -0.001, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	# Soft hills around the edge of the diorama.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240517
	for i in range(16):
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.9, 2.2)
		sphere.height = sphere.radius * rng.randf_range(1.0, 1.8)
		sphere.radial_segments = 16
		sphere.rings = 8
		hill.mesh = sphere
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = GROUND_COLOR.darkened(0.05)
		hmat.roughness = 0.95
		hmat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		hill.material_override = hmat
		var angle := TAU * float(i) / 16.0 + rng.randf_range(-0.12, 0.12)
		var radius := rng.randf_range(6.5, 10.5)
		hill.position = Vector3(cos(angle) * radius, -sphere.radius * 0.85, sin(angle) * radius)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(hill)

	# A little pond.
	var water := MeshInstance3D.new()
	var wplane := PlaneMesh.new()
	wplane.size = Vector2(3.2, 2.4)
	water.mesh = wplane
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = WATER_COLOR
	wmat.roughness = 0.15
	wmat.metallic = 0.25
	water.material_override = wmat
	water.position = Vector3(2.9, 0.004, -2.4)
	add_child(water)


## The original game's island: one flat "ground" quad plus a sculpted
## "scene" mesh with the hills, and the lake around it.
func _build_terrain() -> void:
	var packed: PackedScene = load("res://assets/models/landscape/terrain.glb")
	if packed == null:
		return
	var root: Node3D = packed.instantiate()
	root.scale = Vector3.ONE * 0.1
	add_child(root)

	var ground_tex := _load_tex("res://assets/textures/terrain/lowres/terrainGround_diffuse.jpg")
	var scene_tex := _load_tex("res://assets/textures/terrain/lowres/terrainScene_diffuse.jpg")
	var pattern_tex := _load_tex("res://assets/textures/terrain/lowres/pattern.png")

	for node in _find_named(root):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.92
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		match node.name:
			"ground":
				if ground_tex:
					mat.albedo_texture = ground_tex
			"scene":
				if scene_tex:
					mat.albedo_texture = scene_tex
			"water":
				mat.albedo_color = Color(0.36, 0.66, 0.85)
				mat.roughness = 0.08
				mat.metallic = 0.4
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _find_named(node: Node) -> Array:
	var out: Array = []
	if node.name in ["ground", "scene", "water"]:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_named(child))
	return out


func _build_props() -> void:
	_tree_scene = load("res://assets/models/landscape/tree.glb")
	_grass_scene = load("res://assets/models/landscape/grass.glb")
	_flower_scene = load("res://assets/models/landscape/flower.glb")
	_rock_scene = load("res://assets/models/landscape/rock_a.glb")

	var tree_tex := _load_tex("res://assets/textures/tree/lowres/tree_diffuse.jpg")
	var grass_tex := _load_tex("res://assets/textures/grass/lowres/grass_diffuse.jpg")
	var flower_tex := _load_tex("res://assets/textures/flower/lowres/flower_diffuse.jpg")

	_spawn_group(data.get("trees", []), _tree_scene, tree_tex, 0.1, 0.045, 2.6, 6.0)
	_spawn_group(data.get("grass", []), _grass_scene, grass_tex, 0.1, 0.02, 1.4, 3.4)
	_spawn_group(data.get("flowers", []), _flower_scene, flower_tex, 0.1, 0.012, 1.6, 3.8)
	_spawn_group(data.get("rocks", []), _rock_scene, null, 0.1, 0.03, 1.6, 3.4)


func _spawn_group(entries: Array, scene: PackedScene, tex: Texture2D, model_scale: float,
		base_scale: float, min_r: float, max_r: float) -> void:
	if scene == null:
		return
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if tex:
		mat.albedo_texture = tex
	for entry in entries:
		var node: Node3D = scene.instantiate()
		node.scale = Vector3.ONE * model_scale
		add_child(node)
		_register_prop(node)
		var pos: Dictionary = entry.get("position", {"x": 0, "y": 0, "z": 0})
		# The original data is authored in centimetres and scaled by 0.1.
		node.position = Vector3(pos["x"], pos["z"], -pos["y"]) * model_scale
		var rot: Dictionary = entry.get("rotation", {"x": 0, "y": 0, "z": 0})
		node.rotation = Vector3(rot["x"], rot["z"], rot["y"])
		var sc: Dictionary = entry.get("scale", {"x": 1, "y": 1, "z": 1})
		node.scale = Vector3(sc["x"], sc["z"], sc["y"]) * model_scale
		_apply_material(node, mat)


## Records a scenery object so it can be hidden when the track runs over it.
func _register_prop(node: Node3D) -> void:
	var aabb := AABB()
	var mesh := _find_mesh(node)
	if mesh and mesh.mesh:
		aabb = mesh.mesh.get_aabb()
		aabb = mesh.transform * aabb
	else:
		return
	var centre := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	props.append({"node": node, "center": centre, "radius": radius})


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


## Hides scenery that a new track piece runs through - just like the
## original game does.
func on_track_piece_added(piece: TrackPiece) -> void:
	for prop in props:
		if _prop_hits_piece(prop, piece):
			prop["node"].visible = false


func on_track_piece_removed(piece: TrackPiece, others: Array) -> void:
	for prop in props:
		if not prop["node"].visible:
			var still_hit := false
			for other in others:
				if _prop_hits_piece(prop, other):
					still_hit = true
					break
			if not still_hit:
				prop["node"].visible = true


func _prop_hits_piece(prop: Dictionary, piece: TrackPiece) -> bool:
	var centre: Vector3 = prop["center"]
	var radius: float = prop["radius"]
	for box in piece.world_boxes():
		var bc: Vector3 = box["center"]
		var half: Vector3 = box["half"]
		var axes: Array = box["axes"]
		var d := centre - bc
		# Distance from the prop centre to the box along each of its axes.
		var dist := 0.0
		for i in range(3):
			var ax: Vector3 = axes[i]
			var proj := absf(d.dot(ax)) - half[i]
			if proj > 0.0:
				dist += proj * proj
		if dist <= radius * radius:
			return true
	return false


static func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material(child, mat)


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _build_balloon() -> void:
	var scene := load("res://assets/models/landscape/balloon.glb")
	if scene == null:
		return
	balloon = scene.instantiate()
	balloon.scale = Vector3.ONE * 0.01
	add_child(balloon)
	for entry in data.get("flyPathBalloon", []):
		balloon_path.append(Vector3(entry["x"], entry["z"], -entry["y"]) * 0.1)
	if balloon_path.size() < 2:
		balloon_path = PackedVector3Array([
			Vector3(-0.6, 1.7, 0.3), Vector3(1.2, 2.1, -0.6),
			Vector3(2.4, 1.8, 0.4), Vector3(0.4, 1.5, 0.9),
		])


func update(delta: float) -> void:
	if balloon == null or balloon_path.size() < 2:
		return
	_balloon_t = fposmod(_balloon_t + delta * 0.012, 1.0)
	var count := balloon_path.size()
	var scaled := _balloon_t * float(count)
	var i: int = int(floorf(scaled)) % count
	var j := (i + 1) % count
	var t: float = scaled - floorf(scaled)
	var p := balloon_path[i].lerp(balloon_path[j], t)
	balloon.position = p
	balloon.position.y += sin(_balloon_t * TAU * 3.0) * 0.03
