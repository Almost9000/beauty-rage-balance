class_name StateMachine
extends Node

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var current_state: State = null
var states: Dictionary = {}

func _enter_tree() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)

func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			_register_state(child)
	if initial_state and current_state == null:
		transition_to(initial_state.name)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(target_state_name):
		var node: Node = get_node_or_null(str(target_state_name))
		if node is State:
			_register_state(node)
		else:
			push_warning("StateMachine: State '%s' not found." % target_state_name)
			return

	var target_state: State = states[target_state_name]
	if target_state == current_state:
		return

	var from_name: StringName = current_state.name if current_state != null else &""
	if current_state:
		current_state.exit()

	current_state = target_state
	current_state.enter(msg)
	state_changed.emit(from_name, target_state_name)

func _register_state(state: State) -> void:
	states[state.name] = state
	state.state_machine = self
	if not state.transition_requested.is_connected(_on_child_transition_requested):
		state.transition_requested.connect(_on_child_transition_requested)

func _on_child_entered_tree(node: Node) -> void:
	if node is State:
		_register_state(node)

func _on_child_transition_requested(to: StringName, msg: Dictionary) -> void:
	transition_to(to, msg)
