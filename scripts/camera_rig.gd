class_name CameraRig
extends Node3D
## Three ways of watching the train, matching the original game:
##  * overview    - orbit around the layout while you build
##  * follow      - chase the locomotive
##  * first person- ride in the cab

enum Mode { OVERVIEW, FOLLOW, FIRST_PERSON }

const DEFAULT_POSITION := Vector3(0.0, 0.8, 1.0)
const DEFAULT_TARGET := Vector3(0.0, 0.8, 0.0)

var mode: int = Mode.OVERVIEW
var camera: Camera3D

var railway: Railway
var train: Train

# Overview orbit state.
var orbit_yaw := 0.6
var orbit_pitch := 0.72
var orbit_distance := 2.4
var orbit_target := Vector3.ZERO
var _dragging := false
var _last_mouse := Vector2.ZERO

var _spin_from := 0.0
var _spin_to := 0.0
var _spin_t := 1.0
var _blend := 1.0
var _blend_from_pos := Vector3.ZERO
var _blend_from_target := Vector3.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 55.0
	camera.near = 0.01
	camera.far = 100.0
	add_child(camera)
	camera.global_position = DEFAULT_POSITION
	camera.look_at(DEFAULT_TARGET, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			orbit_distance = clampf(orbit_distance * 0.9, 0.35, 8.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			orbit_distance = clampf(orbit_distance * 1.1, 0.35, 8.0)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		orbit_yaw -= mm.relative.x * 0.008
		orbit_pitch = clampf(orbit_pitch + mm.relative.y * 0.006, 0.08, 1.45)


## Spins the camera once around the scene, like the original's spin button.
func spin() -> void:
	_spin_from = orbit_yaw
	_spin_to = orbit_yaw + TAU
	_spin_t = 0.0


func set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_blend = 0.0
	_blend_from_pos = camera.global_position
	_blend_from_target = _current_target()


func _current_target() -> Vector3:
	if mode == Mode.FIRST_PERSON or mode == Mode.FOLLOW:
		if train:
			return train.cab_transform().origin
	return orbit_target


func update(delta: float) -> void:
	if _spin_t < 1.0:
		_spin_t = minf(1.0, _spin_t + delta * 0.5)
		var e := 1.0 - pow(1.0 - _spin_t, 3.0)
		orbit_yaw = lerpf(_spin_from, _spin_to, e)
	if railway:
		_update_orbit_target()
	var want_pos := Vector3.ZERO
	var want_target := Vector3.ZERO
	match mode:
		Mode.OVERVIEW:
			want_pos = orbit_target + Vector3(
				sin(orbit_yaw) * cos(orbit_pitch),
				sin(orbit_pitch),
				cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
			want_target = orbit_target
		Mode.FOLLOW:
			var cab := train.cab_transform() if train else Transform3D.IDENTITY
			var fwd := -cab.basis.z
			var flat := Vector3(fwd.x, 0.0, fwd.z)
			if flat.length_squared() < 0.000001:
				flat = Vector3(0, 0, 1)
			flat = flat.normalized()
			want_pos = cab.origin - flat * 0.38 + Vector3.UP * 0.20
			want_target = cab.origin + flat * 0.5 + Vector3.UP * 0.01
		Mode.FIRST_PERSON:
			var cab2 := train.cab_transform() if train else Transform3D.IDENTITY
			want_pos = cab2.origin + cab2.basis.z * 0.02 + Vector3.UP * 0.012
			want_target = want_pos + cab2.basis.z * 1.0

	if train:
		# Sitting in the cab means the locomotive must not block the view.
		var hide_train := mode == Mode.FIRST_PERSON and _blend > 0.85
		for car in train.cars:
			car["node"].visible = not hide_train

	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta * 2.0)
		var t := _blend * _blend * (3.0 - 2.0 * _blend)
		var blended_pos := _blend_from_pos.lerp(want_pos, t)
		var blended_target := _blend_from_target.lerp(want_target, t)
		camera.global_position = blended_pos
		camera.look_at(blended_target, Vector3.UP)
	else:
		camera.global_position = want_pos
		camera.look_at(want_target, Vector3.UP)


## Keeps the orbit camera framed on the layout that is being built.
func _update_orbit_target() -> void:
	if railway == null or railway.sequence.is_empty():
		return
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for piece in railway.sequence:
		for p in piece.positions:
			var w: Vector3 = piece.global_transform.basis * p + piece.global_transform.origin
			lo = Vector3(minf(lo.x, w.x), minf(lo.y, w.y), minf(lo.z, w.z))
			hi = Vector3(maxf(hi.x, w.x), maxf(hi.y, w.y), maxf(hi.z, w.z))
	var centre := (lo + hi) * 0.5
	centre.y = maxf(centre.y, 0.02)
	orbit_target = orbit_target.lerp(centre, 0.08)
	var span := maxf(hi.x - lo.x, hi.z - lo.z)
	if span > 0.01:
		orbit_distance = lerpf(orbit_distance, clampf(span * 0.9 + 0.42, 0.75, 3.0), 0.05)
