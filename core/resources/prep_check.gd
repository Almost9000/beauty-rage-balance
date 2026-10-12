class_name PrepCheck
extends Resource

@export var weight: float = 1.0
@export var label: String = ""
@export_range(0.0, 1.0, 0.01) var pass_threshold: float = 0.75


func evaluate() -> float:
	return 0.0


func is_passed(score: float = -1.0) -> bool:
	var s: float = evaluate() if score < 0.0 else score
	return s >= pass_threshold
