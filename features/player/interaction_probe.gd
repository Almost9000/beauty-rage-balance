class_name InteractionProbe
extends Area3D

signal best_candidate_changed(best: Interactable)

@export var prompt_scene: PackedScene
@export var player_node: Node

var current_best: Interactable = null
var _prompt_instance: InteractionPrompt = null
var _prompt_layer: CanvasLayer = null

func _init() -> void:
	collision_layer = 0
	collision_mask = 4

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4

	if not player_node and get_parent() is CharacterBody3D:
		player_node = get_parent()

	_setup_prompt()

func _setup_prompt() -> void:
	var scene: PackedScene = prompt_scene
	if not scene:
		scene = load("res://features/player/interaction_prompt.tscn")
	if scene:
		_prompt_layer = CanvasLayer.new()
		_prompt_layer.layer = 6
		add_child(_prompt_layer)
		var inst: Node = scene.instantiate()
		_prompt_instance = inst as InteractionPrompt
		if _prompt_instance:
			_prompt_layer.add_child(_prompt_instance)
			_prompt_instance.visible = false

func _physics_process(_delta: float) -> void:
	_update_best_candidate()

func _update_best_candidate() -> void:
	var areas: Array[Area3D] = get_overlapping_areas()
	var best_node: Node3D = pick_best(areas, global_position, -global_transform.basis.z)
	var new_best: Interactable = best_node as Interactable

	if new_best != current_best:
		current_best = new_best
		best_candidate_changed.emit(current_best)

	if _prompt_instance:
		if current_best and current_best.enabled and not _is_input_locked():
			_prompt_instance.show_prompt(current_best.prompt_text)
		else:
			_prompt_instance.hide_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _is_input_locked():
			return
		if current_best and current_best.enabled:
			current_best.interact(player_node if player_node else self)
			get_viewport().set_input_as_handled()

func _is_input_locked() -> bool:
	if player_node and player_node.has_method("is_input_locked"):
		return bool(player_node.call("is_input_locked"))
	return false

static func pick_best(candidates: Array, ref_pos: Variant = null, ref_fwd: Variant = null) -> Node3D:
	var pos: Vector3 = ref_pos if ref_pos is Vector3 else Vector3.ZERO
	var fwd: Vector3 = ref_fwd if ref_fwd is Vector3 else Vector3.FORWARD
	if fwd.length_squared() > 0.0001:
		fwd = fwd.normalized()
	else:
		fwd = Vector3.FORWARD

	var valid: Array[Node3D] = []
	for item: Variant in candidates:
		var node: Node3D = item as Node3D
		if not node:
			continue
		if "enabled" in node and not bool(node.get("enabled")):
			continue
		valid.append(node)

	if valid.is_empty():
		return null
	if valid.size() == 1:
		return valid[0]

	valid.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var pa: int = int(a.get("priority")) if "priority" in a else 0
		var pb: int = int(b.get("priority")) if "priority" in b else 0
		if pa != pb:
			return pa > pb

		var pos_a: Vector3 = a.global_position if a.is_inside_tree() else a.position
		var pos_b: Vector3 = b.global_position if b.is_inside_tree() else b.position

		var offset_a: Vector3 = pos_a - pos
		var offset_b: Vector3 = pos_b - pos

		var dist_a: float = offset_a.length()
		var dist_b: float = offset_b.length()

		var dot_a: float = 1.0
		if dist_a > 0.001:
			dot_a = fwd.dot(offset_a / dist_a)

		var dot_b: float = 1.0
		if dist_b > 0.001:
			dot_b = fwd.dot(offset_b / dist_b)

		# Facing bonus minus distance
		var score_a: float = dot_a * 2.0 - dist_a
		var score_b: float = dot_b * 2.0 - dist_b
		return score_a > score_b
	)

	return valid[0]
