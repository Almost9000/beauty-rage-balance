class_name MakeupLook
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## Maps layer key (int Enums.MakeupLayer) -> Dictionary:
## {
##   "cosmetic": CosmeticItem,
##   "opacity": float,
##   "smudge": Vector2,
##   "accuracy": float,
## }
@export var layers: Dictionary = {}


func set_layer(
	layer: Variant,
	cosmetic: CosmeticItem,
	opacity: float = 1.0,
	smudge: Vector2 = Vector2.ZERO,
	accuracy: float = 1.0
) -> void:
	var key: int = int(layer)
	layers[key] = {
		"cosmetic": cosmetic,
		"opacity": clampf(opacity, 0.0, 1.0),
		"smudge": smudge,
		"accuracy": clampf(accuracy, 0.0, 1.0),
	}


func get_layer(layer: Variant) -> Dictionary:
	var key: int = int(layer)
	if layers.has(key):
		return layers[key]
	if layers.has(str(layer)):
		return layers[str(layer)]
	return {}


func has_layer(layer: Variant) -> bool:
	var entry: Dictionary = get_layer(layer)
	return entry.size() > 0 and entry.get("cosmetic") != null


func clear_layer(layer: Variant) -> void:
	var key: int = int(layer)
	layers.erase(key)
	layers.erase(str(layer))


func score() -> float:
	var total_acc: float = 0.0
	var count: int = 0
	for key: Variant in layers.keys():
		var entry: Dictionary = layers[key]
		if entry.get("cosmetic") != null:
			total_acc += float(entry.get("accuracy", 0.0))
			count += 1
	if count == 0:
		return 0.0
	return total_acc / float(count)


func to_dict() -> Dictionary:
	var layers_dict: Dictionary = {}
	for key: Variant in layers.keys():
		var entry: Dictionary = layers[key]
		var cos_ref: String = ""
		var cosmetic: Variant = entry.get("cosmetic")
		if cosmetic is CosmeticItem:
			cos_ref = ResRef.to_ref(cosmetic as CosmeticItem)
			if cos_ref.is_empty() and not (cosmetic as CosmeticItem).resource_path.is_empty():
				cos_ref = (cosmetic as CosmeticItem).resource_path
			if cos_ref.is_empty():
				cos_ref = String((cosmetic as CosmeticItem).id)
		elif cosmetic is String:
			cos_ref = cosmetic
		elif cosmetic is StringName:
			cos_ref = String(cosmetic)

		var smudge_vec: Vector2 = Vector2.ZERO
		var smudge_raw: Variant = entry.get("smudge", Vector2.ZERO)
		if smudge_raw is Vector2:
			smudge_vec = smudge_raw
		elif smudge_raw is Dictionary:
			smudge_vec = Vector2(smudge_raw.get("x", 0.0), smudge_raw.get("y", 0.0))
		elif smudge_raw is Array and smudge_raw.size() >= 2:
			smudge_vec = Vector2(smudge_raw[0], smudge_raw[1])

		layers_dict[str(key)] = {
			"cosmetic": cos_ref,
			"opacity": float(entry.get("opacity", 1.0)),
			"smudge": {"x": smudge_vec.x, "y": smudge_vec.y},
			"accuracy": float(entry.get("accuracy", 1.0)),
		}

	return {
		"id": String(id),
		"display_name": display_name,
		"layers": layers_dict,
	}


static func from_dict(data: Dictionary) -> MakeupLook:
	var look: MakeupLook = MakeupLook.new()
	look.id = StringName(data.get("id", ""))
	look.display_name = data.get("display_name", "")

	var layers_dict: Dictionary = data.get("layers", {})
	for key_variant: Variant in layers_dict.keys():
		var layer_idx: int = int(str(key_variant))
		var entry_dict: Dictionary = layers_dict[key_variant]
		var cos_ref: String = str(entry_dict.get("cosmetic", ""))
		var cos_item: CosmeticItem = null

		if not cos_ref.is_empty():
			var loaded: Resource = ResRef.load_ref(cos_ref)
			if loaded is CosmeticItem:
				cos_item = loaded as CosmeticItem
			elif ResourceLoader.exists(cos_ref):
				var res: Resource = ResourceLoader.load(cos_ref)
				if res is CosmeticItem:
					cos_item = res as CosmeticItem

		var smudge_vec: Vector2 = Vector2.ZERO
		var smudge_val: Variant = entry_dict.get("smudge", {"x": 0.0, "y": 0.0})
		if smudge_val is Dictionary:
			smudge_vec = Vector2(smudge_val.get("x", 0.0), smudge_val.get("y", 0.0))
		elif smudge_val is Array and smudge_val.size() >= 2:
			smudge_vec = Vector2(smudge_val[0], smudge_val[1])
		elif smudge_val is Vector2:
			smudge_vec = smudge_val

		var opacity: float = float(entry_dict.get("opacity", 1.0))
		var accuracy: float = float(entry_dict.get("accuracy", 1.0))

		look.layers[layer_idx] = {
			"cosmetic": cos_item,
			"opacity": clampf(opacity, 0.0, 1.0),
			"smudge": smudge_vec,
			"accuracy": clampf(accuracy, 0.0, 1.0),
		}

	return look
