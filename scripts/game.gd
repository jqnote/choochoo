extends Node3D
## Choo-Choo World - a Godot re-implementation of the wooden train track
## builder from choochooworld.com.

const SHARE_BASE_URL := "https://choochooworld.com/?DATA="

var railway: Railway
var train: Train
var camera_rig: CameraRig
var landscape: Landscape
var ui: UI
var audio: AudioManager

var url := UrlManager.new()
var palette_index := 0
var edit_mode := true
var night_mode := false

var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _sky_material: ProceduralSkyMaterial
var _night_ratio := 0.0
var _night_target := 0.0
var _compatibility := false


func _ready() -> void:
	randomize()
	_build_scene()
	ui = UI.new()
	add_child(ui)
	_connect_ui()
	_parse_command_line()
	_apply_layout()
	_apply_palette()
	_set_mode(true)
	audio.play_music()
	_maybe_run_debug_script()


## Supports `--shot[=frames]`, `--data=<DATA>`, `--mode=edit|view|follow|first`,
## `--night`, `--add=<pieces>`, `--popup=<name>`, `--dump` and `--selftest`
## on the command line so the game can be driven from a script.
func _maybe_run_debug_script() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--mode="):
			var mode := arg.substr(7)
			if mode == "view":
				_set_mode(false)
			elif mode == "first":
				_set_mode(false)
				camera_rig.set_mode(CameraRig.Mode.FIRST_PERSON)
			elif mode == "follow":
				_set_mode(false)
				camera_rig.set_mode(CameraRig.Mode.FOLLOW)
			else:
				_set_mode(true)
		if arg == "--night":
			night_mode = true
			url.day_code = "N"
			_night_target = 1.0
			_night_ratio = 1.0
			_update_day_night()
		if arg.begins_with("--popup="):
			var which := arg.substr(8)
			if which == "share":
				_on_share()
			elif which == "settings":
				ui.show_settings()
			elif which == "about":
				ui.show_about()
			elif which == "delete":
				ui.show_confirm()
		if arg.begins_with("--add="):
			for t in arg.substr(6).split(","):
				railway.add_and_commit(t)
			_apply_palette()
	for arg in args:
		if arg == "--dump":
			print("[Choo-Choo World] layout=", railway.layout(),
				" share=", url.track_code, "/", url.color_palette_code, "/", url.day_code,
				" pieces=", railway.sequence.size())
			get_tree().quit()
			return
	for arg in args:
		if arg == "--selftest":
			SelfTest.run(railway, train)
			SelfTest.test_ui(self)
			SelfTest.test_scenery(self)
			get_tree().quit()
			return
	for arg in args:
		if arg == "--shot" or arg.begins_with("--shot="):
			var frames := 150
			if arg.contains("="):
				frames = int(arg.substr(6))
			await _capture_after(frames)


func _capture_after(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("/tmp/ccw_shot.png")
		print("[Choo-Choo World] screenshot written to /tmp/ccw_shot.png")
	get_tree().quit()


# ------------------------------------------------------------------- scene --

func _build_scene() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("#5ea9e8")
	_sky_material.sky_horizon_color = Color("#cfe9ff")
	_sky_material.ground_horizon_color = Color("#bfe3b0")
	_sky_material.ground_bottom_color = Color("#6fae52")
	_sky_material.sun_angle_max = 12.0
	_sky_material.sun_curve = 0.12

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = _sky_material
	# The compatibility renderer (OpenGL ES on Android) gets its ambient light
	# from the sky much more strongly, so it needs a gentler setup.
	_compatibility = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if _compatibility:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#6f9ec4")
		env.ambient_light_energy = 0.32
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.72 if _compatibility else 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe9ff")
	env.fog_density = 0.012
	_environment = WorldEnvironment.new()
	_environment.environment = env
	add_child(_environment)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48.0, 132.0, 0.0)
	_sun.light_energy = 1.0 if _compatibility else 1.35
	_sun.light_color = Color("#fff6e0")
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 20.0
	add_child(_sun)

	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)

	landscape = Landscape.new()
	landscape.name = "Landscape"
	add_child(landscape)

	railway = Railway.new()
	railway.name = "Railway"
	add_child(railway)

	train = Train.new()
	train.name = "Train"
	add_child(train)
	train.setup(railway)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.railway = railway
	camera_rig.train = train
	add_child(camera_rig)

	railway.loop_completed.connect(_on_loop_completed)
	railway.piece_committed.connect(_on_piece_committed)
	railway.piece_removed.connect(_on_piece_removed)


func _connect_ui() -> void:
	ui.piece_hovered.connect(_on_piece_hovered)
	ui.piece_unhovered.connect(_on_piece_unhovered)
	ui.piece_clicked.connect(_on_piece_clicked)
	ui.palette_selected.connect(_on_palette)
	ui.undo_pressed.connect(_on_undo)
	ui.delete_all_pressed.connect(_on_delete_all)
	ui.camera_mode_selected.connect(_on_camera_mode)
	ui.mode_switched.connect(_on_mode_switch)
	ui.play_pause_pressed.connect(_on_play_pause)
	ui.reset_pressed.connect(_on_reset)
	ui.share_pressed.connect(_on_share)
	ui.snapshot_pressed.connect(_on_snapshot)
	ui.settings_pressed.connect(func() -> void: ui.show_settings())
	ui.about_pressed.connect(func() -> void: ui.show_about())
	ui.day_night_pressed.connect(_on_day_night)
	ui.camera_spin_pressed.connect(_on_camera_spin)
	ui.music_toggled.connect(func(on: bool) -> void: audio.set_music_enabled(on))
	ui.sfx_toggled.connect(func(on: bool) -> void: audio.sfx_enabled = on)
	ui.download_pressed.connect(_on_download_snapshot)


# ------------------------------------------------------------------- setup --

func _parse_command_line() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--data="):
			url.read_from_url("DATA=" + arg.substr(7))
			return
	url.read_from_url("")


func _apply_layout() -> void:
	var layout := url.decoded_layout()
	railway.load_layout(layout)
	url.track_code = UrlManager.encode(railway.layout_codes())
	palette_index = clampi(int(url.color_palette_code), 0, TrackData.COLOR_PALETTES.size() - 1)
	night_mode = url.day_code == "N"
	_night_target = 1.0 if night_mode else 0.0
	_night_ratio = _night_target
	_update_day_night()


func _apply_palette() -> void:
	var palette: Array = TrackData.COLOR_PALETTES[palette_index]
	for i in range(railway.sequence.size()):
		var piece: TrackPiece = railway.sequence[i]
		piece.set_tint(Color(palette[i % palette.size()]))
	if ui:
		ui.set_active_palette(palette_index)


func refresh_colors() -> void:
	_apply_palette()


# ------------------------------------------------------------------ modes --

func _set_mode(edit: bool) -> void:
	edit_mode = edit
	ui.set_switch_label(edit)
	ui.set_editor_visible(edit)
	if edit:
		camera_rig.set_mode(CameraRig.Mode.OVERVIEW)
		train.pause()
		ui.set_play_pause_playing(false)
	else:
		camera_rig.set_mode(CameraRig.Mode.FOLLOW)
		if not train.is_playing:
			train.play()
		ui.set_play_pause_playing(true)


# ------------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_play_pause()
			KEY_R:
				train.reverse = not train.reverse
			KEY_LEFT:
				train.speed_multiplier = clampf(train.speed_multiplier - 0.25, 1.0, 12.0)
			KEY_RIGHT:
				train.speed_multiplier = clampf(train.speed_multiplier + 0.25, 1.0, 12.0)


func _process(delta: float) -> void:
	if train:
		train.update(delta)
	if camera_rig:
		camera_rig.update(delta)
	if landscape:
		landscape.update(delta)
	if audio:
		audio.set_train_running(train.is_playing and train.speed > 0.001, train.speed)
	if train and ui:
		ui.set_needs_reset(train.reached_end)
	if railway:
		_update_button_states()
	if absf(_night_ratio - _night_target) > 0.001:
		_night_ratio = move_toward(_night_ratio, _night_target, delta * 0.7)
		_update_day_night()


func _update_button_states() -> void:
	for type in TrackData.EDITOR_ORDER:
		ui.set_piece_disabled(type, not TrackData.is_allowed_at_level(type, railway.current_level))


# ------------------------------------------------------------------ events --

func _on_piece_hovered(type: String) -> void:
	if edit_mode:
		railway.preview(type)
		audio.play("hover", -18.0)


func _on_piece_unhovered() -> void:
	if edit_mode:
		railway.cancel_preview()


func _on_piece_clicked(type: String) -> void:
	if not edit_mode:
		return
	if railway.preview_piece == null or railway.preview_piece.type != type:
		railway.preview(type)
	if railway.commit_preview():
		url.track_code = UrlManager.encode(railway.layout_codes())
		audio.play("place")
	_apply_palette()


func _on_undo() -> void:
	railway.remove_last_piece()
	audio.play("delete", -6.0)
	url.track_code = UrlManager.encode(railway.layout_codes())
	_apply_palette()


func _on_delete_all() -> void:
	railway.remove_all_pieces()
	audio.play("delete")
	url.track_code = UrlManager.encode(railway.layout_codes())
	_apply_palette()
	train.reset_to_start()


func _on_play_pause() -> void:
	if edit_mode:
		_set_mode(false)
		return
	train.toggle()
	ui.set_play_pause_playing(train.is_playing)
	audio.play("train_start" if train.is_playing else "train_reset", -4.0)


func _on_reset() -> void:
	train.reset_to_start()
	train.pause()
	ui.set_play_pause_playing(false)
	audio.play("train_reset", -4.0)


func _on_palette(index: int) -> void:
	palette_index = index
	url.color_palette_code = str(index)
	_apply_palette()


func _on_camera_mode(mode: int) -> void:
	camera_rig.set_mode(mode)
	audio.play("camera_spin", -8.0)


func _on_camera_spin() -> void:
	camera_rig.spin()
	audio.play("camera_spin", -8.0)


func _on_mode_switch(edit: bool) -> void:
	var was_edit := edit_mode
	_set_mode(edit)
	if was_edit != edit:
		audio.play("build_mode" if edit else "camera_mode", -6.0)


func _on_piece_committed(piece: TrackPiece) -> void:
	if landscape:
		landscape.on_track_piece_added(piece)


func _on_piece_removed(piece: TrackPiece) -> void:
	if landscape:
		var others: Array = []
		for other in railway.sequence:
			if other != piece:
				others.append(other)
		landscape.on_track_piece_removed(piece, others)


func _on_loop_completed() -> void:
	print("[Choo-Choo World] The track is a loop - the train will run forever.")
	audio.play("completed")


func _on_day_night() -> void:
	night_mode = not night_mode
	audio.play("cricket" if night_mode else "hover", -14.0)
	url.day_code = "N" if night_mode else "D"
	_night_target = 1.0 if night_mode else 0.0


func _update_day_night() -> void:
	var t := _night_ratio
	var day_top := Color("#5ea9e8")
	var day_horizon := Color("#cfe9ff")
	var night_top := Color("#080d2c")
	var night_horizon := Color("#2a2170")
	_sky_material.sky_top_color = day_top.lerp(night_top, t)
	_sky_material.sky_horizon_color = day_horizon.lerp(night_horizon, t)
	_sky_material.ground_horizon_color = Color("#bfe3b0").lerp(Color("#16204a"), t)
	_sky_material.ground_bottom_color = Color("#6fae52").lerp(Color("#0b1230"), t)
	_sun.light_energy = lerpf(0.95 if _compatibility else 1.35, 0.18, t)
	_sun.light_color = Color("#fff6e0").lerp(Color("#9fb6ff"), t)
	_sun.rotation_degrees = Vector3(lerpf(-48.0, -22.0, t), 132.0, 0.0)
	var env := _environment.environment
	if _compatibility:
		env.ambient_light_color = Color("#6f9ec4").lerp(Color("#1a2350"), t)
	env.ambient_light_energy = lerpf(0.32 if _compatibility else 1.0, 0.22, t)
	env.fog_light_color = Color("#cfe9ff").lerp(Color("#141a44"), t)


func _on_share() -> void:
	var url_text := SHARE_BASE_URL + "%s/%d/%s" % [url.track_code, palette_index, url.day_code]
	ui.show_share(url_text)


func _on_snapshot() -> void:
	audio.play("snapshot", -6.0)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	ui.show_snapshot(ImageTexture.create_from_image(image))


func _on_download_snapshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var path := "user://choo-choo-world.png"
	var err := image.save_png(path)
	if err == OK:
		print("[Choo-Choo World] Snapshot saved to ", ProjectSettings.globalize_path(path))
