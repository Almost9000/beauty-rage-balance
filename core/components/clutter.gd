class_name Clutter
extends Node3D

@export var clutter_type: StringName = &"dishes"
@export var weight: float = 1.0
@export var clean_time_min: int = 5
@export var reward: Array[StatModifier] = []

@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable

var _cleaned: bool = false

func _ready() -> void:
	if not is_in_group(&"clutter"):
		add_to_group(&"clutter")
	if reward.is_empty():
		_init_default_reward()
	_setup_interactable()

func _init_default_reward() -> void:
	var mod := StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.INSTANT
	mod.source_id = StringName("clean_" + String(clutter_type))
	match clutter_type:
		&"dishes":
			mod.value = 2.0
			mod.label = "Clean dishes"
		&"laundry":
			mod.value = 2.0
			mod.label = "Folded laundry"
		&"trash":
			mod.value = 2.0
			mod.label = "Took out trash"
		&"dog_accident":
			mod.value = 3.0
			mod.label = "Cleaned accident"
		_:
			mod.value = 1.0
			mod.label = "Tidied up"
	reward.append(mod)


func _setup_interactable() -> void:
	if not interactable:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		if interactable.prompt_text.is_empty():
			update_prompt_text()
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func update_prompt_text() -> void:
	if interactable:
		interactable.prompt_text = "Clean %s (%d min)" % [clutter_type, clean_time_min]

func _on_interacted(actor: Node) -> void:
	clean(actor)

func clean(_player: Node = null) -> void:
	if _cleaned:
		return
	_cleaned = true

	if clean_time_min > 0:
		var clock: Node = get_node_or_null("/root/GameClock")
		if clock and clock.has_method("skip"):
			clock.call("skip", clean_time_min)

	if not reward.is_empty():
		var sm: Node = get_node_or_null("/root/StatusManager")
		if sm and sm.has_method("add_modifier"):
			for mod: StatModifier in reward:
				if mod:
					var copy: StatModifier = mod.duplicate() as StatModifier
					if copy.source_id.is_empty():
						copy.source_id = StringName("clean_" + String(clutter_type))
					if copy.is_valid():
						sm.call("add_modifier", copy)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("clutter_cleaned"):
		bus.emit_signal("clutter_cleaned", clutter_type, weight)

	queue_free()
