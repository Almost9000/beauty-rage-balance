class_name FaceMakeup
extends Node

const LAYER_UNIFORMS: Dictionary = {
	Enums.MakeupLayer.BASE: {
		"mask": "base_mask",
		"tint": "base_tint",
		"opacity": "base_opacity",
		"smudge": "base_smudge",
		"default_mask": "res://assets/textures/makeup_masks/mask_base.png",
	},
	Enums.MakeupLayer.BLUSH: {
		"mask": "blush_mask",
		"tint": "blush_tint",
		"opacity": "blush_opacity",
		"smudge": "blush_smudge",
		"default_mask": "res://assets/textures/makeup_masks/mask_blush.png",
	},
	Enums.MakeupLayer.EYESHADOW: {
		"mask": "eyeshadow_mask",
		"tint": "eyeshadow_tint",
		"opacity": "eyeshadow_opacity",
		"smudge": "eyeshadow_smudge",
		"default_mask": "res://assets/textures/makeup_masks/mask_eyeshadow.png",
	},
	Enums.MakeupLayer.EYELINER: {
		"mask": "eyeliner_mask",
		"tint": "eyeliner_tint",
		"opacity": "eyeliner_opacity",
		"smudge": "eyeliner_smudge",
		"default_mask": "res://assets/textures/makeup_masks/mask_eyeliner.png",
	},
	Enums.MakeupLayer.LIPSTICK: {
		"mask": "lipstick_mask",
		"tint": "lipstick_tint",
		"opacity": "lipstick_opacity",
		"smudge": "lipstick_smudge",
		"default_mask": "res://assets/textures/makeup_masks/mask_lipstick.png",
	},
}

@export var body_material: ShaderMaterial
var _default_mask_textures: Dictionary = {}
var _applied_look: MakeupLook = null


func _ready() -> void:
	_load_default_masks()
	_resolve_material()
	_connect_inventory_manager()
	_sync_from_inventory()


func _load_default_masks() -> void:
	for layer: int in LAYER_UNIFORMS.keys():
		var path: String = LAYER_UNIFORMS[layer]["default_mask"]
		if ResourceLoader.exists(path):
			_default_mask_textures[layer] = load(path) as Texture2D


func _resolve_material() -> void:
	if body_material != null:
		return
	var parent_node: Node = get_parent()
	if parent_node:
		if parent_node.has_method("_setup_body_material") and parent_node.get("body_material") == null:
			parent_node.call("_setup_body_material")
		if parent_node.get("body_material") is ShaderMaterial:
			body_material = parent_node.get("body_material") as ShaderMaterial
		elif parent_node.get("body_mesh") is MeshInstance3D:
			var mesh: MeshInstance3D = parent_node.get("body_mesh") as MeshInstance3D
			if mesh and mesh.material_override is ShaderMaterial:
				body_material = mesh.material_override as ShaderMaterial


func _connect_inventory_manager() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv:
		if not inv.is_connected("look_changed", _on_inventory_look_changed):
			inv.connect("look_changed", _on_inventory_look_changed)


func _sync_from_inventory() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and "current_look" in inv and inv.current_look != null:
		apply_look(inv.current_look)
	else:
		clear()


func apply_look(look: MakeupLook) -> void:
	_applied_look = look
	_resolve_material()
	if body_material == null:
		return

	if look == null:
		clear()
		return

	for layer: int in LAYER_UNIFORMS.keys():
		var u_info: Dictionary = LAYER_UNIFORMS[layer]
		if look.has_layer(layer):
			var entry: Dictionary = look.get_layer(layer)
			var cosmetic: CosmeticItem = entry.get("cosmetic") as CosmeticItem
			var opacity: float = float(entry.get("opacity", 1.0))
			var smudge: Vector2 = entry.get("smudge", Vector2.ZERO)

			var mask_tex: Texture2D = null
			if cosmetic and cosmetic.mask != null:
				mask_tex = cosmetic.mask
			elif _default_mask_textures.has(layer):
				mask_tex = _default_mask_textures[layer]

			var tint: Color = cosmetic.tint if cosmetic else Color.WHITE

			if mask_tex != null:
				body_material.set_shader_parameter(u_info["mask"], mask_tex)
			body_material.set_shader_parameter(u_info["tint"], tint)
			body_material.set_shader_parameter(u_info["opacity"], opacity)
			body_material.set_shader_parameter(u_info["smudge"], smudge)
		else:
			_clear_single_layer(layer)


func clear() -> void:
	_applied_look = null
	_resolve_material()
	if body_material == null:
		return

	for layer: int in LAYER_UNIFORMS.keys():
		_clear_single_layer(layer)


func _clear_single_layer(layer: int) -> void:
	if body_material == null or not LAYER_UNIFORMS.has(layer):
		return
	var u_info: Dictionary = LAYER_UNIFORMS[layer]
	body_material.set_shader_parameter(u_info["opacity"], 0.0)
	body_material.set_shader_parameter(u_info["smudge"], Vector2.ZERO)
	body_material.set_shader_parameter(u_info["tint"], Color.WHITE)


func set_layer_opacity(layer: Enums.MakeupLayer, opacity: float) -> void:
	_resolve_material()
	if body_material == null:
		return
	var key: int = int(layer)
	if LAYER_UNIFORMS.has(key):
		var u_info: Dictionary = LAYER_UNIFORMS[key]
		body_material.set_shader_parameter(u_info["opacity"], clampf(opacity, 0.0, 1.0))


func set_layer_smudge(layer: Enums.MakeupLayer, smudge: Vector2) -> void:
	_resolve_material()
	if body_material == null:
		return
	var key: int = int(layer)
	if LAYER_UNIFORMS.has(key):
		var u_info: Dictionary = LAYER_UNIFORMS[key]
		body_material.set_shader_parameter(u_info["smudge"], smudge)


func get_applied_look() -> MakeupLook:
	return _applied_look


func _on_inventory_look_changed(look: MakeupLook) -> void:
	apply_look(look)
