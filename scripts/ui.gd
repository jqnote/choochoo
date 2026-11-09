class_name UI
extends CanvasLayer
## The heads-up display. Everything is built in code so the layout can follow
## the original game's arrangement:
##   top right      - settings / snapshot / share / about
##   right middle   - play & reset
##   bottom left    - track editor and camera mode
##   bottom right   - edit / view switch
##   bottom middle  - colour palettes

signal piece_hovered(type: String)
signal piece_unhovered
signal piece_clicked(type: String)
signal palette_selected(index: int)
signal undo_pressed
signal delete_all_pressed
signal camera_mode_selected(mode: int)
signal mode_switched(edit: bool)
signal play_pause_pressed
signal reset_pressed
signal share_pressed
signal snapshot_pressed
signal settings_pressed
signal about_pressed
signal day_night_pressed
signal camera_spin_pressed
signal music_toggled(enabled: bool)
signal sfx_toggled(enabled: bool)

const BLUE := Color("#0f7fd4")
const BLUE_DARK := Color("#0158b4")
const ORANGE := Color("#f59d0c")
const ORANGE_DARK := Color("#d36601")

var piece_buttons: Dictionary = {}
var palette_buttons: Array = []
var play_pause_button: Control
var reset_button: Control
var switch_button: Button
var camera_buttons: Dictionary = {}
var share_popup: Control
var settings_popup: Control
var confirm_popup: Control
var snapshot_popup: Control
var about_popup: Control
var _snapshot_image: TextureRect
var _share_url_field: LineEdit
var _play_pause_icon
var _reset_hint := false
var _editor_row: HBoxContainer


func _ready() -> void:
	layer = 10
	set_process(true)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_header(root)
	_build_player(root)
	_build_footer(root)
	_build_palettes(root)
	_build_popups(root)


func _process(delta: float) -> void:
	if not _reset_hint or reset_button == null:
		return
	var t := float(Time.get_ticks_msec()) * 0.004
	var pulse := 1.0 + 0.25 * sin(t)
	reset_button.modulate = Color(pulse, pulse * 0.92, pulse * 0.92)


# ------------------------------------------------------------------ helpers --

func _icon_button(icon: String, box: Vector2, bg: Color, bg_dark: Color, tooltip: String = "") -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	holder.size = box
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	if tooltip != "":
		holder.tooltip_text = tooltip

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 4.0
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = int(box.x * 0.28)
	style.corner_radius_top_right = int(box.x * 0.28)
	style.corner_radius_bottom_left = int(box.x * 0.28)
	style.corner_radius_bottom_right = int(box.x * 0.28)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)

	var icon_rect := TextureRect.new()
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_top = 4
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "" and ResourceLoader.exists(icon):
		icon_rect.texture = load(icon)
	holder.add_child(icon_rect)

	holder.mouse_entered.connect(func() -> void:
		holder.modulate = Color(1.12, 1.12, 1.12))
	holder.mouse_exited.connect(func() -> void:
		holder.modulate = Color.WHITE)
	return holder


func _label_button(text: String, box: Vector2, bg: Color, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = box
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	if tooltip != "":
		b.tooltip_text = tooltip
	return b


# ------------------------------------------------------------------- header --

func _build_header(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.position = Vector2(-40, 26)
	bar.add_theme_constant_override("separation", 26)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var defs := [
		["res://assets/images/header/settings/settings_00000.png", "Settings", "settings_pressed"],
		["res://assets/images/header/snapshot/snapshot_00000.png", "Take a snapshot", "snapshot_pressed"],
		["res://assets/images/header/share/share_00000.png", "Share your track", "share_pressed"],
		["res://assets/images/header/about/about_00000.png", "About", "about_pressed"],
	]
	for def in defs:
		var btn := _icon_button(def[0], Vector2(34, 34), Color(1, 1, 1, 0), Color(1, 1, 1, 0), def[1])
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := btn.get_child(1) as TextureRect
		if icon:
			icon.offset_top = 0
		bar.add_child(btn)
		var kind: String = def[2]
		match kind:
			"settings_pressed":
				btn.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed:
						settings_pressed.emit())
			"snapshot_pressed":
				btn.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed:
						snapshot_pressed.emit())
			"share_pressed":
				btn.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed:
						share_pressed.emit())
			"about_pressed":
				btn.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed:
						about_pressed.emit())

	# Day / night switch.
	var day := _icon_button("", Vector2(34, 34), Color(1, 1, 1, 0), Color(1, 1, 1, 0), "Day / night")
	var day_label := Label.new()
	day_label.text = "☀"
	day_label.add_theme_font_size_override("font_size", 22)
	day_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day.add_child(day_label)
	day.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			day_night_pressed.emit())
	bar.add_child(day)


# ------------------------------------------------------------------- player --

func _build_player(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-96, 0)
	box.add_theme_constant_override("separation", 16)
	root.add_child(box)

	play_pause_button = _icon_button("", Vector2(62, 62), BLUE, BLUE_DARK, "Play the train")
	_play_pause_icon = PlayPauseIcon.new()
	_play_pause_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_pause_icon.offset_top = 6
	_play_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_pause_button.add_child(_play_pause_icon)
	play_pause_button.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			play_pause_pressed.emit())
	box.add_child(play_pause_button)

	reset_button = _icon_button("res://assets/images/player/station/station-active.png",
		Vector2(62, 62), ORANGE, ORANGE_DARK, "Go back to the station")
	reset_button.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			reset_pressed.emit())
	box.add_child(reset_button)


# ------------------------------------------------------------------- footer --

func _build_footer(root: Control) -> void:
	var footer := VBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 30
	footer.offset_right = -30
	footer.offset_top = -176
	footer.offset_bottom = -22
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)

	# Upper row: colour palettes on the left, camera modes on the right.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(top_row)
	var palette_box := HBoxContainer.new()
	palette_box.add_theme_constant_override("separation", 6)
	palette_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(palette_box)
	for i in range(TrackData.COLOR_PALETTES.size()):
		var pbtn := _icon_button("res://assets/images/tracks/colors/color_%d.png" % i,
			Vector2(34, 34), Color(1, 1, 1, 0), Color(1, 1, 1, 0), "Colour palette %d" % (i + 1))
		pbtn.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				palette_selected.emit(i))
		palette_box.add_child(pbtn)
		palette_buttons.append(pbtn)

	var cameras := HBoxContainer.new()
	cameras.add_theme_constant_override("separation", 8)
	cameras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(cameras)
	for def in [["res://assets/images/camera/train.png", "Follow it", CameraRig.Mode.FOLLOW],
			["res://assets/images/camera/first-person.png", "First person", CameraRig.Mode.FIRST_PERSON]]:
		var cbtn := _icon_button(def[0], Vector2(50, 50), BLUE, BLUE_DARK, def[1])
		cbtn.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				camera_mode_selected.emit(def[2]))
		cameras.add_child(cbtn)
		camera_buttons[def[2]] = cbtn
	var spin_btn := _icon_button("res://assets/images/camera/cameraSpin/cameraSpinAnimation.png",
		Vector2(50, 50), ORANGE, ORANGE_DARK, "Spin the camera around the track")
	spin_btn.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			camera_spin_pressed.emit())
	cameras.add_child(spin_btn)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	# Lower row: the track editor on the left, the edit/view switch on the right.
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(bottom_row)
	_editor_row = bottom_row
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(left)

	# Track editor.
	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 6)
	editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(editor)

	var undo := _icon_button("res://assets/images/tracks/delete/delete.png",
		Vector2(50, 50), BLUE, BLUE_DARK, "Delete the last piece")
	undo.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			undo_pressed.emit())
	editor.add_child(undo)

	var bin := _icon_button("res://assets/images/tracks/bin/bin.png",
		Vector2(50, 50), BLUE, BLUE_DARK, "Delete the whole track")
	bin.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			show_confirm())
	editor.add_child(bin)

	for type in TrackData.EDITOR_ORDER:
		var def: Dictionary = TrackData.get_piece(type)
		var icon: String = def["icon"]
		var btn := _icon_button(icon, Vector2(50, 50), BLUE, BLUE_DARK, def["name"])
		btn.mouse_entered.connect(func() -> void: piece_hovered.emit(type))
		btn.mouse_exited.connect(func() -> void: piece_unhovered.emit())
		btn.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				piece_clicked.emit(type))
		editor.add_child(btn)
		piece_buttons[type] = btn

	# Edit / view switch on the far right.
	switch_button = Button.new()
	switch_button.text = "Edit"
	switch_button.custom_minimum_size = Vector2(118, 50)
	switch_button.size_flags_vertical = Control.SIZE_SHRINK_END
	switch_button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = ORANGE
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	switch_button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = ORANGE.lightened(0.12)
	switch_button.add_theme_stylebox_override("hover", hover)
	switch_button.pressed.connect(func() -> void:
		mode_switched.emit(switch_button.text == "Edit"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(spacer)
	bottom_row.add_child(switch_button)


func set_switch_label(edit: bool) -> void:
	switch_button.text = "Edit" if edit else "View"


## The track editor is only available while building.
func set_editor_visible(visible_now: bool) -> void:
	if _editor_row:
		_editor_row.visible = visible_now


# ----------------------------------------------------------------- palettes --

func _build_palettes(_root: Control) -> void:
	# The palette buttons are created together with the footer.
	pass


func set_active_palette(index: int) -> void:
	for i in range(palette_buttons.size()):
		var btn: Control = palette_buttons[i]
		btn.modulate = Color.WHITE if i == index else Color(0.55, 0.55, 0.55)


func set_piece_disabled(type: String, disabled: bool) -> void:
	if not piece_buttons.has(type):
		return
	var btn: Control = piece_buttons[type]
	btn.modulate = Color(0.4, 0.4, 0.4, 0.75) if disabled else Color.WHITE


## Pulses the "back to the station" button when the train has run out of track.
func set_needs_reset(needed: bool) -> void:
	_reset_hint = needed
	reset_button.modulate = Color(1.35, 1.2, 1.2) if needed else Color.WHITE


func set_play_pause_playing(playing: bool) -> void:
	if _play_pause_icon:
		_play_pause_icon.playing = playing
		_play_pause_icon.queue_redraw()


## The little triangle / double bar that shows whether the train is running.
class PlayPauseIcon:
	extends Control
	var playing := false

	func _draw() -> void:
		var c := size * 0.5
		var white := Color(1, 1, 1)
		if playing:
			var bar := size.x * 0.13
			var h := size.y * 0.42
			draw_rect(Rect2(c.x - size.x * 0.22, c.y - h * 0.5, bar, h), white)
			draw_rect(Rect2(c.x + size.x * 0.09, c.y - h * 0.5, bar, h), white)
		else:
			var r := size.x * 0.24
			var points := PackedVector2Array([
				Vector2(c.x - r * 0.8, c.y - r),
				Vector2(c.x - r * 0.8, c.y + r),
				Vector2(c.x + r, c.y),
			])
			draw_colored_polygon(points, white)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ------------------------------------------------------------------- popups --

func _popup(root: Control, title: String) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.99, 1.0)
	style.set_corner_radius_all(20)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", BLUE_DARK)
	vb.add_child(lbl)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			panel.visible = false
			dim.visible = false)
	return panel


func _build_popups(root: Control) -> void:
	share_popup = _popup(root, "Share your track")
	var share_vb := share_popup.get_child(0)
	var info := Label.new()
	info.text = "Send this link to a friend - it opens the same layout in Choo-Choo World."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
	share_vb.add_child(info)
	_share_url_field = LineEdit.new()
	_share_url_field.custom_minimum_size = Vector2(460, 42)
	_share_url_field.editable = false
	share_vb.add_child(_share_url_field)
	var copy := _label_button("Copy link", Vector2(140, 44), BLUE, "Copy the link to the clipboard")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_share_url_field.text)
		copy.text = "Copied!")
	share_vb.add_child(copy)

	settings_popup = _popup(root, "Settings")
	var set_vb := settings_popup.get_child(0)
	var music := CheckButton.new()
	music.text = "Music"
	music.button_pressed = true
	music.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
	music.add_theme_color_override("font_pressed_color", Color(0.25, 0.28, 0.36))
	music.add_theme_color_override("font_hover_color", Color(0.25, 0.28, 0.36))
	music.toggled.connect(func(on: bool) -> void: music_toggled.emit(on))
	set_vb.add_child(music)
	var audio := CheckButton.new()
	audio.text = "Sound effects"
	audio.button_pressed = true
	audio.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
	audio.add_theme_color_override("font_pressed_color", Color(0.25, 0.28, 0.36))
	audio.add_theme_color_override("font_hover_color", Color(0.25, 0.28, 0.36))
	audio.toggled.connect(func(on: bool) -> void: sfx_toggled.emit(on))
	set_vb.add_child(audio)
	var help := Label.new()
	help.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
	help.text = "Controls\n  Space - play / pause the train\n  R - reverse direction\n  Left / Right arrow - speed\n  Drag - orbit the camera\n  Scroll - zoom"
	set_vb.add_child(help)

	confirm_popup = _popup(root, "Do you want to delete all?")
	var conf_vb := confirm_popup.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	conf_vb.add_child(row)
	var no := _label_button("No, cancel", Vector2(160, 46), Color(0.85, 0.87, 0.92), "Cancel")
	no.pressed.connect(func() -> void: hide_confirm())
	row.add_child(no)
	var yes := _label_button("Yes, delete all", Vector2(180, 46), Color(0.88, 0.32, 0.32), "Delete everything")
	yes.pressed.connect(func() -> void:
		hide_confirm()
		delete_all_pressed.emit())
	row.add_child(yes)

	snapshot_popup = _popup(root, "Your snapshot")
	_snapshot_image = TextureRect.new()
	_snapshot_image.custom_minimum_size = Vector2(480, 300)
	_snapshot_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	snapshot_popup.get_child(0).add_child(_snapshot_image)
	var download := _label_button("Download image", Vector2(200, 46), BLUE, "Save the picture")
	download.pressed.connect(func() -> void: download_pressed.emit())
	snapshot_popup.get_child(0).add_child(download)

	about_popup = _popup(root, "About Choo-Choo World")
	var about_vb := about_popup.get_child(0)
	var about_text := Label.new()
	about_text.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
	about_text.text = "Choo-Choo World\nA wooden train track builder.\n\nThis version is a re-implementation in Godot of the original web game by choochooworld.com."
	about_vb.add_child(about_text)


signal download_pressed


func show_share(url: String) -> void:
	_share_url_field.text = url
	_toggle(share_popup, true)


func show_settings() -> void:
	_toggle(settings_popup, true)


func show_about() -> void:
	_toggle(about_popup, true)


func show_confirm() -> void:
	_toggle(confirm_popup, true)


func hide_confirm() -> void:
	_toggle(confirm_popup, false)


func show_snapshot(image: Texture2D) -> void:
	_snapshot_image.texture = image
	_toggle(snapshot_popup, true)


func _toggle(panel: Control, visible_now: bool) -> void:
	panel.visible = visible_now
	var dim := panel.get_parent().get_child(panel.get_index() - 1)
	if dim is ColorRect:
		dim.visible = visible_now
