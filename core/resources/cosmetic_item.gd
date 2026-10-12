class_name CosmeticItem
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var layer: Enums.MakeupLayer = Enums.MakeupLayer.BASE
@export var tint: Color = Color.WHITE
@export var price_cents: int = 0
@export var icon: Texture2D
@export var mask: Texture2D = null


func is_valid() -> bool:
	return not id.is_empty()
