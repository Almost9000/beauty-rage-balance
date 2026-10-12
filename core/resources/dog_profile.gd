class_name DogProfile
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var mesh_scene: PackedScene
@export var scale: Vector3 = Vector3.ONE
@export var speed: float = 2.0

# Decay rates per game hour (0.0 to 100.0 scale)
# hunger & bladder increase over time; affection & energy decrease over time
@export var hunger_decay_per_hour: float = 6.0
@export var bladder_decay_per_hour: float = 10.0
@export var affection_decay_per_hour: float = 8.0
@export var energy_decay_per_hour: float = 6.0

# Request / Critical thresholds (0.0 to 100.0)
@export var hunger_threshold: float = 70.0
@export var bladder_threshold: float = 70.0
@export var affection_threshold: float = 30.0
@export var energy_threshold: float = 20.0

@export var bark_interval_min: int = 20


func get_decay_per_hour(need: StringName) -> float:
	match need:
		&"hunger":
			return hunger_decay_per_hour
		&"bladder":
			return bladder_decay_per_hour
		&"affection":
			return affection_decay_per_hour
		&"energy":
			return energy_decay_per_hour
		_:
			return 0.0


func get_threshold(need: StringName) -> float:
	match need:
		&"hunger":
			return hunger_threshold
		&"bladder":
			return bladder_threshold
		&"affection":
			return affection_threshold
		&"energy":
			return energy_threshold
		_:
			return 50.0
