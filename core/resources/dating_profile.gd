class_name DatingProfile
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var age: int = 25
@export_multiline var bio: String = ""
@export var photo: Texture2D = null
@export var green_flags: Array[String] = []
@export var red_flags: Array[String] = []
@export_range(0.0, 1.0, 0.01) var match_chance: float = 0.5
@export var date_outing: OutingData = null
@export var tags: Array[String] = []


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty()
