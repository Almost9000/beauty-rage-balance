class_name MakeupCheck
extends PrepCheck

@export_range(0.0, 1.0, 0.01) var min_score: float = 0.7
@export var makeup_optional: bool = false


func _init() -> void:
	label = "Makeup"
	weight = 1.0
	pass_threshold = 1.0


func evaluate() -> float:
	var inv: Node = null
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		inv = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("InventoryManager")
	if inv == null:
		inv = InventoryManager

	var look: MakeupLook = null
	if inv != null and "current_look" in inv:
		look = inv.get("current_look") as MakeupLook

	var has_cosmetics: bool = false
	if look != null:
		for k: Variant in look.layers.keys():
			var entry: Dictionary = look.layers[k]
			if entry.get("cosmetic") != null:
				has_cosmetics = true
				break

	if not has_cosmetics:
		return 1.0 if makeup_optional else 0.0

	var look_score: float = look.score()
	if min_score <= 0.0:
		return 1.0
	if look_score >= min_score:
		return 1.0
	if look_score <= 0.0:
		return 0.0
	return clampf(look_score / min_score, 0.0, 1.0)
