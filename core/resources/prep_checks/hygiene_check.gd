class_name HygieneCheck
extends PrepCheck

@export var min_hygiene: float = 70.0


func _init() -> void:
	label = "Hygiene"
	weight = 1.0
	pass_threshold = 1.0


func evaluate() -> float:
	if min_hygiene <= 0.0:
		return 1.0

	var sm: Node = null
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		sm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("StatusManager")
	if sm == null:
		sm = StatusManager

	var hygiene: float = 0.0
	if sm != null:
		if sm.has_method("get_stat"):
			hygiene = float(sm.call("get_stat", "hygiene"))
		elif sm.has_method("get_value"):
			hygiene = float(sm.call("get_value", Enums.Stat.HYGIENE))

	if hygiene >= min_hygiene:
		return 1.0
	if hygiene <= 0.0:
		return 0.0
	return clampf(hygiene / min_hygiene, 0.0, 1.0)
