class_name Shower
extends Node3D

@export var duration_min: int = 15
@export var effects: Array[StatModifier] = []
@export var fade_duration: float = 0.3

@onready var interactable: Interactable = $Interactable
@onready var fade_rect: ColorRect = get_node_or_null("FadeCanvas/FadeOverlay") as ColorRect

var _is_showering: bool = false


func _ready() -> void:
	if effects.is_empty():
		_init_default_effects()
	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if fade_rect:
		fade_rect.color.a = 0.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init_default_effects() -> void:
	var hy_mod := StatModifier.new()
	hy_mod.stat = Enums.Stat.HYGIENE
	hy_mod.kind = Enums.ModifierKind.INSTANT
	hy_mod.value = 40.0
	hy_mod.source_id = &"prep_shower"
	hy_mod.label = "Hot shower"

	var sa_mod := StatModifier.new()
	sa_mod.stat = Enums.Stat.SANITY
	sa_mod.kind = Enums.ModifierKind.INSTANT
	sa_mod.value = 10.0
	sa_mod.source_id = &"prep_shower"
	sa_mod.label = "Shower relaxation"

	effects.append(hy_mod)
	effects.append(sa_mod)


func _on_interacted(actor: Node) -> void:
	start_shower(actor)


## Callable directly without UI / animations for unit testing
func execute_action(_actor: Node = null) -> void:
	if effects.is_empty():
		_init_default_effects()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", duration_min)

	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("add_modifier"):
		for mod: StatModifier in effects:
			if mod:
				sm.call("add_modifier", mod)


func start_shower(actor: Node) -> void:
	if _is_showering:
		return
	_is_showering = true

	if is_instance_valid(actor) and actor.has_method("lock_input"):
		actor.lock_input(&"shower")

	# Screen fade out
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_out: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out.tween_property(fade_rect, "color:a", 1.0, fade_duration)
		await fade_out.finished

	# Apply game action logic
	execute_action(actor)

	# Screen fade in
	if fade_rect:
		var fade_in: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_in.tween_property(fade_rect, "color:a", 0.0, fade_duration)
		await fade_in.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(actor) and actor.has_method("unlock_input"):
		actor.unlock_input(&"shower")

	_is_showering = false


func is_showering() -> bool:
	return _is_showering
