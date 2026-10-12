class_name SwipeCard
extends Control

signal swiped_left(profile: DatingProfile)
signal swiped_right(profile: DatingProfile)

@export var swipe_threshold: float = 80.0
@export var flick_velocity_threshold: float = 400.0
@export var tween_duration: float = 0.22
@export var snap_back_duration: float = 0.18
@export var rotation_factor: float = 0.0008
@export var max_rotation: float = 0.4

var profile: DatingProfile = null

@onready var photo_rect: TextureRect = $CardPanel/MarginContainer/CardVBox/PhotoContainer/PhotoRect
@onready var name_age_label: Label = $CardPanel/MarginContainer/CardVBox/InfoVBox/InfoMargin/HeaderHBox/NameAgeLabel
@onready var bio_label: Label = $CardPanel/MarginContainer/CardVBox/InfoVBox/BioMargin/BioLabel
@onready var green_flags_list: VBoxContainer = $CardPanel/MarginContainer/CardVBox/InfoVBox/FlagsScroll/FlagsVBox/FlagsMargin/FlagsContent/GreenFlagsSection/GreenFlagsList
@onready var red_flags_list: VBoxContainer = $CardPanel/MarginContainer/CardVBox/InfoVBox/FlagsScroll/FlagsVBox/FlagsMargin/FlagsContent/RedFlagsSection/RedFlagsList
@onready var like_stamp: PanelContainer = $LikeStamp
@onready var pass_stamp: PanelContainer = $PassStamp

var _initial_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _is_swiping: bool = false
var _drag_start_global: Vector2 = Vector2.ZERO
var _last_global: Vector2 = Vector2.ZERO
var _last_time_ms: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _tween: Tween = null


func _ready() -> void:
	_initial_pos = position
	mouse_filter = Control.MOUSE_FILTER_STOP
	if like_stamp:
		like_stamp.modulate.a = 0.0
	if pass_stamp:
		pass_stamp.modulate.a = 0.0


func set_profile(p: DatingProfile) -> void:
	profile = p
	if profile == null:
		return

	if name_age_label:
		name_age_label.text = "%s, %d" % [profile.display_name, profile.age]

	if bio_label:
		bio_label.text = tr(profile.bio)

	if photo_rect:
		photo_rect.texture = profile.photo

	_populate_flags(green_flags_list, profile.green_flags, true)
	_populate_flags(red_flags_list, profile.red_flags, false)


func _populate_flags(container: VBoxContainer, flags: Array[String], is_green: bool) -> void:
	if not container:
		return

	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for flag: String in flags:
		var badge := PanelContainer.new()
		var style := StyleBoxFlat.new()
		if is_green:
			style.bg_color = Color(0.12, 0.28, 0.18, 0.9)
			style.border_color = Color(0.28, 0.75, 0.45, 0.8)
		else:
			style.bg_color = Color(0.32, 0.12, 0.15, 0.9)
			style.border_color = Color(0.85, 0.35, 0.35, 0.8)

		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.set_corner_radius_all(6)
		style.content_margin_left = 6.0
		style.content_margin_top = 3.0
		style.content_margin_right = 6.0
		style.content_margin_bottom = 3.0
		badge.add_theme_stylebox_override("panel", style)

		var lbl := Label.new()
		var prefix: String = "✓ " if is_green else "⚑ "
		lbl.text = prefix + tr(flag)
		lbl.add_theme_font_size_override("font_size", 11)
		var text_col: Color = Color(0.5, 0.95, 0.65) if is_green else Color(1.0, 0.6, 0.6)
		lbl.add_theme_color_override("font_color", text_col)
		badge.add_child(lbl)

		container.add_child(badge)


func _gui_input(event: InputEvent) -> void:
	if _is_swiping:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.global_position)
			accept_event()
		elif _is_dragging:
			_end_drag()
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		_process_drag(event.global_position)
		accept_event()


func _start_drag(global_pos: Vector2) -> void:
	_is_dragging = true
	_drag_start_global = global_pos
	_last_global = global_pos
	_last_time_ms = Time.get_ticks_msec()
	_velocity = Vector2.ZERO
	_kill_tween()


func _process_drag(global_pos: Vector2) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var dt: float = float(now_ms - _last_time_ms) / 1000.0
	if dt > 0.001:
		_velocity = (global_pos - _last_global) / dt
		_last_global = global_pos
		_last_time_ms = now_ms

	var offset: Vector2 = global_pos - _drag_start_global
	position = _initial_pos + Vector2(offset.x, offset.y * 0.25)
	rotation = clampf(offset.x * rotation_factor, -max_rotation, max_rotation)

	if offset.x > 10.0:
		var ratio: float = clampf(offset.x / swipe_threshold, 0.0, 1.0)
		if like_stamp:
			like_stamp.modulate.a = ratio
		if pass_stamp:
			pass_stamp.modulate.a = 0.0
	elif offset.x < -10.0:
		var ratio: float = clampf(-offset.x / swipe_threshold, 0.0, 1.0)
		if pass_stamp:
			pass_stamp.modulate.a = ratio
		if like_stamp:
			like_stamp.modulate.a = 0.0
	else:
		if like_stamp:
			like_stamp.modulate.a = 0.0
		if pass_stamp:
			pass_stamp.modulate.a = 0.0


func _end_drag() -> void:
	_is_dragging = false
	var offset_x: float = position.x - _initial_pos.x
	if offset_x > swipe_threshold or _velocity.x > flick_velocity_threshold:
		swipe_right()
	elif offset_x < -swipe_threshold or _velocity.x < -flick_velocity_threshold:
		swipe_left()
	else:
		snap_back()


func snap_back() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position", _initial_pos, snap_back_duration)
	_tween.parallel().tween_property(self, "rotation", 0.0, snap_back_duration)
	if like_stamp:
		_tween.parallel().tween_property(like_stamp, "modulate:a", 0.0, snap_back_duration)
	if pass_stamp:
		_tween.parallel().tween_property(pass_stamp, "modulate:a", 0.0, snap_back_duration)


func swipe_right(immediate: bool = false) -> void:
	if _is_swiping:
		return
	_is_swiping = true
	_kill_tween()

	if like_stamp:
		like_stamp.modulate.a = 1.0
	if pass_stamp:
		pass_stamp.modulate.a = 0.0

	var p: DatingProfile = profile
	if immediate or tween_duration <= 0.0:
		_is_swiping = false
		swiped_right.emit(p)
		return

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var target_pos := _initial_pos + Vector2(600.0, 40.0)
	_tween.parallel().tween_property(self, "position", target_pos, tween_duration)
	_tween.parallel().tween_property(self, "rotation", 0.35, tween_duration)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, tween_duration)
	_tween.finished.connect(func() -> void:
		_is_swiping = false
		swiped_right.emit(p)
	)


func swipe_left(immediate: bool = false) -> void:
	if _is_swiping:
		return
	_is_swiping = true
	_kill_tween()

	if pass_stamp:
		pass_stamp.modulate.a = 1.0
	if like_stamp:
		like_stamp.modulate.a = 0.0

	var p: DatingProfile = profile
	if immediate or tween_duration <= 0.0:
		_is_swiping = false
		swiped_left.emit(p)
		return

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var target_pos := _initial_pos + Vector2(-600.0, 40.0)
	_tween.parallel().tween_property(self, "position", target_pos, tween_duration)
	_tween.parallel().tween_property(self, "rotation", -0.35, tween_duration)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, tween_duration)
	_tween.finished.connect(func() -> void:
		_is_swiping = false
		swiped_left.emit(p)
	)


func reset_card() -> void:
	_is_swiping = false
	_is_dragging = false
	_kill_tween()
	position = _initial_pos
	rotation = 0.0
	modulate.a = 1.0
	if like_stamp:
		like_stamp.modulate.a = 0.0
	if pass_stamp:
		pass_stamp.modulate.a = 0.0


func set_initial_pos(pos: Vector2) -> void:
	_initial_pos = pos
	position = pos


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
