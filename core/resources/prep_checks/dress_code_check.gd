class_name DressCodeCheck
extends PrepCheck

@export var required_tags: Array[StringName] = []
@export var forbidden_tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var condition_weight: float = 0.3


func _init() -> void:
	label = "Dress Code"
	weight = 1.0
	pass_threshold = 0.75


func evaluate() -> float:
	var inv: Node = null
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		inv = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("InventoryManager")
	if inv == null:
		inv = InventoryManager

	if inv == null:
		return 0.0

	var equipped_dict: Dictionary = inv.get("equipped") if "equipped" in inv else {}
	var items: Array[ClothingItem] = []
	for slot_key: Variant in equipped_dict.keys():
		var it: ClothingItem = equipped_dict[slot_key] as ClothingItem
		if it != null:
			items.append(it)

	if items.is_empty():
		return 0.0

	# Calculate average condition
	var total_condition: float = 0.0
	var all_tags: Array[StringName] = []
	for it: ClothingItem in items:
		total_condition += clampf(it.condition, 0.0, 1.0)
		for tag: StringName in it.style_tags:
			if not all_tags.has(tag):
				all_tags.append(tag)

	var avg_condition: float = total_condition / float(items.size())

	# Check forbidden tags
	var has_forbidden: bool = false
	for f_tag: StringName in forbidden_tags:
		if all_tags.has(f_tag):
			has_forbidden = true
			break

	# Check required tags
	var req_score: float = 1.0
	if not required_tags.is_empty():
		var matched: int = 0
		for r_tag: StringName in required_tags:
			if all_tags.has(r_tag):
				matched += 1
		req_score = float(matched) / float(required_tags.size())

	var tag_score: float = 0.0 if has_forbidden else req_score
	var clamped_cond_w: float = clampf(condition_weight, 0.0, 1.0)
	var final_score: float = (1.0 - clamped_cond_w) * tag_score + clamped_cond_w * avg_condition
	return clampf(final_score, 0.0, 1.0)
