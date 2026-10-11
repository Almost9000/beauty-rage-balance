extends Node

signal level_changing(from_id: String, to_id: String)
signal level_changed(level_id: String)

const FADE_DURATION: float = 0.3

var current_level_id: String = ""

var _pending_spawn_id: StringName = &"default"
var _level_states: Dictionary = {}
var _is_transitioning: bool = false

var _canvas_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "RouterFadeCanvas"
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeOverlay"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fade_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_canvas_layer.add_child(_fade_rect)

func change_level(level_path: String, spawn_id: StringName = &"default") -> void:
	if _is_transitioning:
		push_warning("SceneRouter: Transition already in progress, ignoring change_level to '%s'" % level_path)
		return

	_is_transitioning = true
	_pending_spawn_id = spawn_id
	var to_id: String = level_path.get_file().get_basename()
	var from_id: String = current_level_id

	level_changing.emit(from_id, to_id)

	if _fade_rect:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_out_tween: Tween = create_tween()
		fade_out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade_out_tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
		await fade_out_tween.finished

	var err: Error = get_tree().change_scene_to_file(level_path)
	if err != OK:
		push_error("SceneRouter: Failed to load scene '%s', error: %d" % [level_path, err])
		if _fade_rect:
			var abort_tween: Tween = create_tween()
			abort_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			abort_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
			await abort_tween.finished
			_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return

	await get_tree().process_frame
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != level_path:
		await get_tree().process_frame

	current_level_id = to_id
	level_changed.emit(current_level_id)

	if _fade_rect:
		var fade_in_tween: Tween = create_tween()
		fade_in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade_in_tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
		await fade_in_tween.finished
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_is_transitioning = false

func consume_spawn_id() -> StringName:
	var id: StringName = _pending_spawn_id
	_pending_spawn_id = &"default"
	if id.is_empty():
		return &"default"
	return id

func store_level_state(level_id: String, data: Dictionary) -> void:
	_level_states[level_id] = data.duplicate(true)

func get_level_state(level_id: String) -> Dictionary:
	var state: Variant = _level_states.get(level_id, {})
	if state is Dictionary:
		return (state as Dictionary).duplicate(true)
	return {}

func reset_state() -> void:
	_level_states.clear()
	current_level_id = ""
	_pending_spawn_id = &"default"
	_is_transitioning = false
	if _fade_rect:
		_fade_rect.color.a = 0.0
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func to_dict() -> Dictionary:
	return {
		"current_level_id": current_level_id,
		"level_states": _level_states.duplicate(true),
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	current_level_id = str(data.get("current_level_id", ""))
	_level_states.clear()
	var states: Variant = data.get("level_states", {})
	if states is Dictionary:
		for k: Variant in (states as Dictionary).keys():
			var val: Variant = (states as Dictionary)[k]
			if val is Dictionary:
				_level_states[str(k)] = (val as Dictionary).duplicate(true)
			else:
				_level_states[str(k)] = val
	_pending_spawn_id = &"default"
