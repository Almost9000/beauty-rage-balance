class_name OutfitSlots
extends Node3D

@export var skeleton: Skeleton3D
@export var body_mesh: MeshInstance3D
@export var animation_player: AnimationPlayer
@export var body_material: ShaderMaterial

var _equipped_items: Dictionary = {}  # Enums.Slot -> ClothingItem
var _slot_meshes: Dictionary = {}     # Enums.Slot -> Array[MeshInstance3D]
var _hidden_regions: int = 0


func _ready() -> void:
	_resolve_nodes()
	_setup_body_material()
	_connect_inventory_manager()
	_sync_from_inventory()
	if animation_player and animation_player.has_animation("Idle"):
		animation_player.play("Idle")


func _resolve_nodes() -> void:
	if skeleton == null:
		skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if body_mesh == null:
		if skeleton:
			body_mesh = skeleton.find_child("Superhero_Female", true, false) as MeshInstance3D
			if body_mesh == null:
				for child in skeleton.get_children():
					if child is MeshInstance3D:
						body_mesh = child as MeshInstance3D
						break
		else:
			body_mesh = find_child("Superhero_Female", true, false) as MeshInstance3D
	if animation_player == null:
		animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer


func _setup_body_material() -> void:
	if body_material == null and body_mesh != null:
		var shader: Shader = load("res://features/avatar/body_regions.gdshader") as Shader
		if shader:
			body_material = ShaderMaterial.new()
			body_material.shader = shader
			var albedo_tex = load("res://assets/models/characters/base_body/base_body_T_Superhero_Female_Dark_BaseColor.png") as Texture2D
			if albedo_tex:
				body_material.set_shader_parameter("albedo_texture", albedo_tex)
			var normal_tex = load("res://assets/models/characters/base_body/base_body_T_Superhero_Female_Normal.png") as Texture2D
			if normal_tex:
				body_material.set_shader_parameter("normal_texture", normal_tex)
			var rough_tex = load("res://assets/models/characters/base_body/base_body_T_Superhero_Female_Roughness.png") as Texture2D
			if rough_tex:
				body_material.set_shader_parameter("roughness_texture", rough_tex)
			body_mesh.material_override = body_material
	elif body_mesh and body_material:
		body_mesh.material_override = body_material


func _connect_inventory_manager() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv:
		if not inv.is_connected("outfit_changed", _on_inventory_outfit_changed):
			inv.connect("outfit_changed", _on_inventory_outfit_changed)


func _sync_from_inventory() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv and "equipped" in inv:
		var equipped_dict: Dictionary = inv.equipped
		for slot_variant: Variant in equipped_dict.keys():
			var item: ClothingItem = equipped_dict.get(slot_variant) as ClothingItem
			if item:
				equip(item)


func equip(item: ClothingItem) -> void:
	if item == null:
		return

	# Slot collision rules
	if item.slot == Enums.Slot.DRESS:
		unequip(Enums.Slot.TOP)
		unequip(Enums.Slot.BOTTOM)
	elif item.slot == Enums.Slot.TOP or item.slot == Enums.Slot.BOTTOM:
		unequip(Enums.Slot.DRESS)

	# Unequip existing item in target slot
	unequip(item.slot)

	_equipped_items[item.slot] = item

	# Instantiate mesh scene and attach skinned meshes to skeleton
	if item.mesh_scene and skeleton:
		var instance: Node = item.mesh_scene.instantiate()
		var mesh_list: Array[MeshInstance3D] = []
		_collect_mesh_instances(instance, mesh_list)

		var attached_meshes: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in mesh_list:
			mesh.owner = null
			if mesh.get_parent():
				mesh.get_parent().remove_child(mesh)
			skeleton.add_child(mesh)
			mesh.skeleton = NodePath("..")
			attached_meshes.append(mesh)

		_slot_meshes[item.slot] = attached_meshes
		instance.queue_free()

	_update_hidden_regions()


func unequip(slot: Enums.Slot) -> void:
	if _slot_meshes.has(slot):
		var mesh_array: Array = _slot_meshes[slot]
		for mesh_variant: Variant in mesh_array:
			var mesh: MeshInstance3D = mesh_variant as MeshInstance3D
			if is_instance_valid(mesh):
				mesh.queue_free()
		_slot_meshes.erase(slot)

	_equipped_items.erase(slot)
	_update_hidden_regions()


func get_equipped(slot: Enums.Slot) -> ClothingItem:
	return _equipped_items.get(slot, null)


func get_slot_meshes(slot: Enums.Slot) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if _slot_meshes.has(slot):
		for item: Variant in _slot_meshes[slot]:
			if item is MeshInstance3D and is_instance_valid(item):
				result.append(item as MeshInstance3D)
	return result


func _collect_mesh_instances(node: Node, out_array: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_array.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_mesh_instances(child, out_array)


func _update_hidden_regions() -> void:
	var mask: int = 0
	for slot_variant: Variant in _equipped_items.keys():
		var item: ClothingItem = _equipped_items[slot_variant] as ClothingItem
		if item:
			mask |= item.hides_regions
	set_hidden_regions(mask)


func set_hidden_regions(mask: int) -> void:
	_hidden_regions = mask
	if body_material:
		body_material.set_shader_parameter("hidden_regions", mask)
	elif body_mesh and body_mesh.material_override is ShaderMaterial:
		(body_mesh.material_override as ShaderMaterial).set_shader_parameter("hidden_regions", mask)


func get_hidden_regions() -> int:
	return _hidden_regions


func set_movement_speed(speed: float, max_speed: float = 4.0) -> void:
	if animation_player == null:
		return
	if speed > 0.1:
		if animation_player.current_animation != "Walk":
			animation_player.play("Walk", 0.2)
		animation_player.speed_scale = clampf(speed / max(0.001, max_speed), 0.5, 1.5)
	else:
		if animation_player.current_animation != "Idle":
			animation_player.play("Idle", 0.2)
		animation_player.speed_scale = 1.0


func _on_inventory_outfit_changed(slot: Enums.Slot, item: ClothingItem) -> void:
	if item != null:
		equip(item)
	else:
		unequip(slot)
