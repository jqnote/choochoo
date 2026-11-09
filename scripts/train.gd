class_name Train
extends Node3D
## The little wooden locomotive and its two log wagons.

signal reached_end_of_track

const CAR_DEFS := [
	{
		"name": "carriage",
		"model": "res://assets/models/train/carriageWithLog.glb",
		"texture": "res://assets/textures/train/carriageWithLog/lowres/carriageWithLog_diffuse.jpg",
		"wheelbase": 0.057,
	},
	{
		"name": "carriage",
		"model": "res://assets/models/train/carriageWithLog.glb",
		"texture": "res://assets/textures/train/carriageWithLog/lowres/carriageWithLog_diffuse.jpg",
		"wheelbase": 0.057,
	},
	{
		"name": "cab",
		"model": "res://assets/models/train/cab.glb",
		"texture": "res://assets/textures/train/cab/lowres/cab_diffuse.jpg",
		"wheelbase": 0.062,
	},
]

const SPEED_TARGET := 0.25
const SPEED_DURATION := 1.0
const WHEEL_HEIGHT := 0.027
const CAR_GAP := 0.01

var railway: Railway
var cars: Array = []
## Distance travelled along the line.
var progress := 0.0
var speed := 0.0
var speed_from := 0.0
var speed_to := 0.0
var speed_started_at := 0.0
var speed_multiplier := 1.0
var reverse := false
var is_playing := false
## True once the locomotive has run off the end of an open line.
var reached_end := false
var _clock := 0.0
var _total_length := 0.0


func setup(rail: Railway) -> void:
	railway = rail
	for i in range(CAR_DEFS.size()):
		var def: Dictionary = CAR_DEFS[i]
		var holder := Node3D.new()
		holder.name = "Car%d" % i
		add_child(holder)
		var packed: PackedScene = load(def["model"])
		var node: Node = packed.instantiate()
		holder.add_child(node)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1)
		mat.roughness = 0.7
		mat.metallic = 0.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tex_path: String = def["texture"]
		if tex_path != "" and ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)
		_apply_material(node, mat)
		var mesh := _find_mesh(node)
		var dims := {
			"total_length": 0.0,
			"back": 0.0,
			"front": 0.0,
			"wheelbase": def["wheelbase"],
		}
		if mesh and mesh.mesh:
			var aabb := mesh.mesh.get_aabb()
			dims["total_length"] = aabb.size.z
			dims["back"] = absf(aabb.position.z)
			dims["front"] = aabb.size.z - absf(aabb.position.z) - def["wheelbase"]
		if def["name"] == "cab":
			var light := SpotLight3D.new()
			light.light_color = Color(1.0, 0.96, 0.82)
			light.light_energy = 2.2
			light.spot_range = 1.6
			light.spot_angle = 32.0
			light.spot_attenuation = 0.6
			light.position = Vector3(0.0, 0.028, 0.03)
			light.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
			holder.add_child(light)
		cars.append({
			"node": holder,
			"dims": dims,
			"base": 0.0,
		})
	# The wagons trail behind the locomotive, each spaced by its own length.
	var acc := 0.0
	for i in range(cars.size()):
		var dims: Dictionary = cars[i]["dims"]
		cars[i]["base"] = acc + dims["back"]
		acc += dims["total_length"] + CAR_GAP
		_total_length = acc


static func _apply_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material(child, mat)


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


## Puts the train back at the station.
func reset_to_start() -> void:
	progress = 0.0
	speed = 0.0
	speed_from = 0.0
	speed_to = 0.0
	reached_end = false
	_place_cars()


func play() -> void:
	is_playing = true
	speed_from = speed
	speed_to = SPEED_TARGET
	speed_started_at = _clock


func pause() -> void:
	is_playing = false
	speed_from = speed
	speed_to = 0.0
	speed_started_at = _clock


func toggle() -> void:
	if is_playing:
		pause()
	else:
		play()


func update(delta: float) -> void:
	_clock += delta
	var t: float = clampf((_clock - speed_started_at) / SPEED_DURATION, 0.0, 1.0)
	speed = lerpf(speed_from, speed_to, _quad_in_out(t)) * speed_multiplier
	speed_multiplier = clampf(speed_multiplier - 2.0 * delta, 1.0, 12.0)
	if is_playing and not reached_end:
		progress += speed * delta * (-1.0 if reverse else 1.0)
	_place_cars()
	if reached_end and speed > 0.0:
		# The end of the line: slow down and stop.
		speed_from = speed
		speed_to = 0.0
		speed_started_at = _clock
		is_playing = false


static func _quad_in_out(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5


func _place_cars() -> void:
	if railway == null:
		return
	for car in cars:
		var dims: Dictionary = car["dims"]
		var base: float = car["base"]
		var rear := railway.sample_track(progress + base)
		var front := railway.sample_track(progress + base + dims["wheelbase"])
		if rear.is_empty() or front.is_empty():
			reached_end = true
			continue
		var up: Vector3 = (rear["up"] + front["up"]).normalized()
		var pos: Vector3 = rear["position"] + up * WHEEL_HEIGHT
		var fwd: Vector3 = (front["position"] - rear["position"])
		if fwd.length_squared() < 0.0000001:
			continue
		fwd = fwd.normalized()
		var right: Vector3 = up.cross(fwd)
		if right.length_squared() < 0.0000001:
			right = Vector3.RIGHT
		right = right.normalized()
		var true_up: Vector3 = fwd.cross(right).normalized()
		var node: Node3D = car["node"]
		node.global_transform = Transform3D(Basis(right, true_up, fwd), pos)


## Position of the locomotive, used by the camera rig.
func cab_transform() -> Transform3D:
	if cars.is_empty():
		return global_transform
	return cars[cars.size() - 1]["node"].global_transform
