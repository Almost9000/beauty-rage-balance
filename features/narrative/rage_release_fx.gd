class_name RageReleaseFx
extends CanvasLayer

signal played()

@onready var flash_overlay: ColorRect = $FlashOverlay

var _tween: Tween = null


func _ready() -> void:
	if flash_overlay:
		flash_overlay.color = Color(0.95, 0.15, 0.35, 0.0)
		flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var nm: Node = get_node_or_null("/root/NarrativeManager")
	if nm and not nm.is_connected("event_finished", _on_event_finished):
		nm.connect("event_finished", _on_event_finished)


func play() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	if flash_overlay:
		flash_overlay.color = Color(0.95, 0.15, 0.35, 0.5)

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Flash fade out
	if flash_overlay:
		_tween.tween_property(flash_overlay, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Impact shake on CanvasLayer offset
	var shake_tween: Tween = create_tween()
	shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shake_tween.tween_property(self, "offset", Vector2(-10.0, 6.0), 0.03)
	shake_tween.tween_property(self, "offset", Vector2(8.0, -5.0), 0.03)
	shake_tween.tween_property(self, "offset", Vector2(-6.0, 4.0), 0.04)
	shake_tween.tween_property(self, "offset", Vector2(4.0, -2.0), 0.04)
	shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.05)

	# Camera 3D shake if viewport camera exists
	var vp: Viewport = get_viewport()
	if vp:
		var cam: Camera3D = vp.get_camera_3d()
		if cam:
			var cam_tween: Tween = create_tween()
			cam_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			cam_tween.tween_property(cam, "h_offset", 0.08, 0.03)
			cam_tween.tween_property(cam, "h_offset", -0.06, 0.03)
			cam_tween.tween_property(cam, "h_offset", 0.03, 0.04)
			cam_tween.tween_property(cam, "h_offset", 0.0, 0.05)

	played.emit()


func _on_event_finished(_event: NarrativeEvent, choice: NarrativeChoice) -> void:
	if choice and choice.stance == Enums.Stance.ASSERT:
		play()
