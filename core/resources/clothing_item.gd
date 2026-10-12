class_name ClothingItem
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Enums.Slot = Enums.Slot.TOP
@export var mesh_scene: PackedScene
@export_flags("HEAD:1", "TORSO:2", "ARMS:4", "HANDS:8", "LEGS:16", "FEET:32") var hides_regions: int = 0
@export var style_tags: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var condition: float = 1.0
@export var price_cents: int = 0
@export var modifiers: Array[StatModifier] = []
@export var icon: Texture2D

func is_valid() -> bool:
	return not id.is_empty() and mesh_scene != null
