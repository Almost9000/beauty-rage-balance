class_name MakeupMinigame
extends CanvasLayer

signal closed()
signal finished(look: MakeupLook)

const LAYERS: Array[Enums.MakeupLayer] = [
	Enums.MakeupLayer.BASE,
	Enums.MakeupLayer.BLUSH,
	Enums.MakeupLayer.EYESHADOW,
	Enums.MakeupLayer.EYELINER,
	Enums.MakeupLayer.LIPSTICK,
]

const LAYER_NAMES: Dictionary = {
	Enums.MakeupLayer.BASE: "Base",
	Enums.MakeupLayer.BLUSH: "Blush",
	Enums.MakeupLayer.EYESHADOW: "Eyeshadow",
	Enums.MakeupLayer.EYELINER: "Eyeliner",
	Enums.MakeupLayer.LIPSTICK: "Lipstick",
}

const GUIDE_PATHS: Dictionary = {
	Enums.MakeupLayer.BASE: "res://data/looks/guides/base.tres",
	Enums.MakeupLayer.BLUSH: "res://data/looks/guides/blush.tres",
	Enums.MakeupLayer.EYESHADOW: "res://data/looks/guides/eyeshadow.tres",
	Enums.MakeupLayer.EYELINER: "res://data/looks/guides/eyeliner.tres",
	Enums.MakeupLayer.LIPSTICK: "res://data/looks/guides/lipstick.tres",
}

@onready var panel_root: Control = $PanelRoot
@onready var title_label: Label = $PanelRoot/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var step_label: Label = $PanelRoot/MarginContainer/VBoxContainer/Header/StepLabel
@onready var close_button: Button = $PanelRoot/MarginContainer/VBoxContainer/Header/CloseButton

@onready var main_content: Control = $PanelRoot/MarginContainer/VBoxContainer/MainHBox
@onready var layer_title: Label = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/LayerTitle
@onready var cosmetics_list: VBoxContainer = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/ScrollContainer/CosmeticsList
@onready var apply_button: Button = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/Actions/ApplyButton
@onready var skip_button: Button = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/Actions/SkipButton
@onready var auto_trace_button: Button = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/Actions/AutoTraceButton
@onready var clear_stroke_button: Button = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/Sidebar/MarginContainer/VBoxContainer/Actions/ClearStrokeButton

@onready var tracing_canvas: Control = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/CenterArea/TracingCanvas
@onready var guide_line: Line2D = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/CenterArea/TracingCanvas/GuideLine
@onready var stroke_line: Line2D = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/CenterArea/TracingCanvas/StrokeLine
@onready var prompt_label: Label = $PanelRoot/MarginContainer/VBoxContainer/MainHBox/CenterArea/TracingCanvas/PromptLabel

@onready var finish_panel: Control = $PanelRoot/MarginContainer/VBoxContainer/FinishPanel
@onready var finish_score_label: Label = $PanelRoot/MarginContainer/VBoxContainer/FinishPanel/VBoxContainer/ScoreLabel
@onready var finish_summary_vbox: VBoxContainer = $PanelRoot/MarginContainer/VBoxContainer/FinishPanel/VBoxContainer/SummaryVBox
@onready var finish_apply_button: Button = $PanelRoot/MarginContainer/VBoxContainer/FinishPanel/VBoxContainer/FinishButton

var is_open: bool = false
var _current_actor: Node = null
var _face_makeup: FaceMakeup = null
var _original_look: MakeupLook = null
var _working_look: MakeupLook = null
var _current_layer_idx: int = 0
var _current_guide: MakeupGuide = null
var _selected_cosmetic: CosmeticItem = null

var _is_drawing: bool = false
var _stroke_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	if panel_root:
		panel_root.visible = false
	if finish_panel:
		finish_panel.visible = false

	_connect_ui_signals()


func _connect_ui_signals() -> void:
	if close_button and not close_button.pressed.is_connected(cancel):
		close_button.pressed.connect(cancel)
	if apply_button and not apply_button.pressed.is_connected(apply_current_layer):
		apply_button.pressed.connect(apply_current_layer)
	if skip_button and not skip_button.pressed.is_connected(skip_current_layer):
		skip_button.pressed.connect(skip_current_layer)
	if auto_trace_button and not auto_trace_button.pressed.is_connected(auto_trace):
		auto_trace_button.pressed.connect(auto_trace)
	if clear_stroke_button and not clear_stroke_button.pressed.is_connected(clear_stroke):
		clear_stroke_button.pressed.connect(clear_stroke)
	if finish_apply_button and not finish_apply_button.pressed.is_connected(finish):
		finish_apply_button.pressed.connect(finish)

	if tracing_canvas:
		if not tracing_canvas.gui_input.is_connected(_on_canvas_gui_input):
			tracing_canvas.gui_input.connect(_on_canvas_gui_input)
		if not tracing_canvas.resized.is_connected(_on_canvas_resized):
			tracing_canvas.resized.connect(_on_canvas_resized)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func open(actor: Node = null) -> void:
	is_open = true
	_current_actor = actor
	_face_makeup = _find_face_makeup(_current_actor)

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and "current_look" in inv and inv.current_look != null:
		_original_look = inv.current_look
	else:
		_original_look = null

	_working_look = MakeupLook.new()
	_working_look.id = &"vanity_custom"
	_working_look.display_name = "Custom Look"

	# Initialize working look from existing layers if present
	if _original_look != null:
		for k: Variant in _original_look.layers.keys():
			var entry: Dictionary = _original_look.layers[k]
			_working_look.layers[k] = entry.duplicate()

	_current_layer_idx = 0
	if panel_root:
		panel_root.visible = true
	if main_content:
		main_content.visible = true
	if finish_panel:
		finish_panel.visible = false

	_setup_layer(_current_layer_idx)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if panel_root:
		panel_root.visible = false
	closed.emit()


func cancel() -> void:
	if not is_open:
		return

	# Revert to original look on avatar and inventory
	if _face_makeup:
		_face_makeup.apply_look(_original_look)

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("set_look"):
		inv.call("set_look", _original_look)

	close()


func finish() -> void:
	if not is_open:
		return

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("set_look"):
		inv.call("set_look", _working_look)

	if _face_makeup:
		_face_makeup.apply_look(_working_look)

	finished.emit(_working_look)
	close()


func get_current_layer() -> Enums.MakeupLayer:
	if _current_layer_idx >= 0 and _current_layer_idx < LAYERS.size():
		return LAYERS[_current_layer_idx]
	return Enums.MakeupLayer.BASE


func get_working_look() -> MakeupLook:
	return _working_look


func get_current_guide() -> MakeupGuide:
	return _current_guide


func _setup_layer(idx: int) -> void:
	if idx < 0 or idx >= LAYERS.size():
		_show_finish_screen()
		return

	_current_layer_idx = idx
	var layer: Enums.MakeupLayer = LAYERS[idx]
	var layer_name: String = LAYER_NAMES.get(layer, "Makeup")

	if step_label:
		step_label.text = "Step %d of %d: %s" % [idx + 1, LAYERS.size(), layer_name]
	if layer_title:
		layer_title.text = layer_name

	_load_guide(layer)
	clear_stroke()
	_update_guide_line()

	_populate_cosmetics(layer)


func _load_guide(layer: Enums.MakeupLayer) -> void:
	var path: String = GUIDE_PATHS.get(layer, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		_current_guide = load(path) as MakeupGuide
	else:
		_current_guide = MakeupGuide.new()
		_current_guide.layer = layer
		_current_guide.points = PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.5)])
		_current_guide.width = 0.05
		_current_guide.time_cost_min = 5
		_current_guide.opacity_range = Vector2(0.2, 0.95)
		_current_guide.max_smudge = 0.03


func _populate_cosmetics(layer: Enums.MakeupLayer) -> void:
	if not cosmetics_list:
		return

	for child in cosmetics_list.get_children():
		cosmetics_list.remove_child(child)
		child.queue_free()

	_selected_cosmetic = null

	var inv: Node = get_node_or_null("/root/InventoryManager")
	var owned: Array[CosmeticItem] = []
	if inv and "owned_cosmetics" in inv:
		for item: CosmeticItem in inv.owned_cosmetics:
			if item and item.layer == layer:
				owned.append(item)

	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No owned cosmetics for this layer."
		empty_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		cosmetics_list.add_child(empty_lbl)
		if apply_button:
			apply_button.disabled = true
		if auto_trace_button:
			auto_trace_button.disabled = true
		return

	# Pre-select existing equipped item for this layer or first owned
	var default_item: CosmeticItem = owned[0]
	if _working_look and _working_look.has_layer(layer):
		var prev: CosmeticItem = _working_look.get_layer(layer).get("cosmetic") as CosmeticItem
		if prev != null and owned.has(prev):
			default_item = prev

	for item: CosmeticItem in owned:
		var btn := _create_cosmetic_button(item, item == default_item)
		cosmetics_list.add_child(btn)

	select_cosmetic(default_item)


func _create_cosmetic_button(item: CosmeticItem, is_default: bool) -> Button:
	var btn := Button.new()
	btn.name = "Cosmetic_" + String(item.id)
	btn.text = " " + item.display_name
	btn.custom_minimum_size = Vector2(0, 36)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	btn.button_pressed = is_default

	# Color swatch preview icon via custom StyleBox or icon
	var swatch := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	swatch.fill(item.tint)
	var tex := ImageTexture.create_from_image(swatch)
	btn.icon = tex

	btn.pressed.connect(func() -> void:
		select_cosmetic(item)
	)
	return btn


func select_cosmetic(item: CosmeticItem) -> void:
	_selected_cosmetic = item

	# Update toggle states in cosmetics list
	if cosmetics_list:
		for child in cosmetics_list.get_children():
			if child is Button:
				var is_match: bool = child.name == "Cosmetic_" + String(item.id)
				child.set_pressed_no_signal(is_match)

	if apply_button:
		apply_button.disabled = false
	if auto_trace_button:
		auto_trace_button.disabled = false

	# Update stroke color feedback
	if stroke_line and item != null:
		var col: Color = item.tint
		col.a = 0.95
		stroke_line.default_color = col


func set_stroke_points(pts: PackedVector2Array) -> void:
	_stroke_points = pts
	_update_stroke_line()


func clear_stroke() -> void:
	_stroke_points.clear()
	if stroke_line:
		stroke_line.points = PackedVector2Array()


func auto_trace() -> void:
	if _current_guide:
		set_stroke_points(_current_guide.points.duplicate())


func apply_current_layer() -> void:
	if not is_open or _selected_cosmetic == null or _current_guide == null:
		return

	var layer: Enums.MakeupLayer = get_current_layer()

	# Score player's stroke
	var score_res: Dictionary = StrokeScorer.score_stroke(_current_guide, _stroke_points)

	# Deduct time on GameClock
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", _current_guide.time_cost_min)

	# Record in working look
	_working_look.set_layer(
		layer,
		_selected_cosmetic,
		float(score_res.get("opacity", 1.0)),
		score_res.get("smudge", Vector2.ZERO) as Vector2,
		float(score_res.get("accuracy", 1.0))
	)

	# Live preview on avatar
	if _face_makeup:
		_face_makeup.apply_look(_working_look)

	# Advance to next layer
	_advance_layer()


func skip_current_layer() -> void:
	if not is_open:
		return

	var layer: Enums.MakeupLayer = get_current_layer()
	_working_look.clear_layer(layer)

	if _face_makeup:
		_face_makeup.apply_look(_working_look)

	_advance_layer()


func _advance_layer() -> void:
	_current_layer_idx += 1
	if _current_layer_idx < LAYERS.size():
		_setup_layer(_current_layer_idx)
	else:
		_show_finish_screen()


func _show_finish_screen() -> void:
	if main_content:
		main_content.visible = false
	if finish_panel:
		finish_panel.visible = true

	var final_score: float = _working_look.score()
	if finish_score_label:
		finish_score_label.text = "Look Score: %d%%" % int(round(final_score * 100.0))

	if finish_summary_vbox:
		for child in finish_summary_vbox.get_children():
			finish_summary_vbox.remove_child(child)
			child.queue_free()

		for layer: Enums.MakeupLayer in LAYERS:
			var layer_name: String = LAYER_NAMES.get(layer, "Layer")
			var lbl := Label.new()
			if _working_look.has_layer(layer):
				var entry: Dictionary = _working_look.get_layer(layer)
				var cos: CosmeticItem = entry.get("cosmetic") as CosmeticItem
				var cos_name: String = cos.display_name if cos else "Applied"
				var acc: int = int(round(float(entry.get("accuracy", 1.0)) * 100.0))
				lbl.text = "• %s: %s (%d%% accuracy)" % [layer_name, cos_name, acc]
				lbl.add_theme_color_override("font_color", Color("#6ee7b7"))
			else:
				lbl.text = "• %s: Skipped" % layer_name
				lbl.add_theme_color_override("font_color", Color("#94a3b8"))
			finish_summary_vbox.add_child(lbl)

	if finish_apply_button:
		finish_apply_button.grab_focus()


func _on_canvas_gui_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_drawing = true
				_stroke_points.clear()
				_add_stroke_pos(mb.position)
			else:
				_is_drawing = false
	elif event is InputEventMouseMotion and _is_drawing:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_add_stroke_pos(mm.position)


func _add_stroke_pos(local_pos: Vector2) -> void:
	if not tracing_canvas or tracing_canvas.size.x <= 0 or tracing_canvas.size.y <= 0:
		return

	var norm := Vector2(
		clampf(local_pos.x / tracing_canvas.size.x, 0.0, 1.0),
		clampf(local_pos.y / tracing_canvas.size.y, 0.0, 1.0)
	)

	if _stroke_points.is_empty() or _stroke_points[-1].distance_to(norm) >= 0.005:
		_stroke_points.append(norm)
		_update_stroke_line()


func _update_guide_line() -> void:
	if not guide_line or not tracing_canvas or _current_guide == null:
		return

	var sz: Vector2 = tracing_canvas.size
	var pts := PackedVector2Array()
	for p: Vector2 in _current_guide.points:
		pts.append(Vector2(p.x * sz.x, p.y * sz.y))
	guide_line.points = pts
	guide_line.width = maxf(4.0, _current_guide.width * sz.x)


func _update_stroke_line() -> void:
	if not stroke_line or not tracing_canvas:
		return

	var sz: Vector2 = tracing_canvas.size
	var pts := PackedVector2Array()
	for p: Vector2 in _stroke_points:
		pts.append(Vector2(p.x * sz.x, p.y * sz.y))
	stroke_line.points = pts
	var w: float = _current_guide.width if _current_guide else 0.04
	stroke_line.width = maxf(4.0, w * sz.x)


func _on_canvas_resized() -> void:
	_update_guide_line()
	_update_stroke_line()


func _find_face_makeup(actor: Node) -> FaceMakeup:
	if actor == null:
		return null
	if "avatar" in actor and actor.avatar != null:
		if actor.avatar.has_node("FaceMakeup") and actor.avatar.get_node("FaceMakeup") is FaceMakeup:
			return actor.avatar.get_node("FaceMakeup") as FaceMakeup
	if actor.has_node("AvatarMount/Avatar/FaceMakeup"):
		return actor.get_node("AvatarMount/Avatar/FaceMakeup") as FaceMakeup
	if actor is OutfitSlots and actor.has_node("FaceMakeup"):
		return actor.get_node("FaceMakeup") as FaceMakeup
	for child in actor.find_children("*", "FaceMakeup", true, false):
		if child is FaceMakeup:
			return child as FaceMakeup
	return null
