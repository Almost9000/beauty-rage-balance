class_name MakeupGuide
extends Resource

@export var layer: Enums.MakeupLayer = Enums.MakeupLayer.BASE
@export var points: PackedVector2Array = PackedVector2Array()
@export var width: float = 0.04
@export var time_cost_min: int = 5
@export var opacity_range: Vector2 = Vector2(0.2, 0.95)
@export var max_smudge: float = 0.03


func is_valid() -> bool:
	return not points.is_empty() and width > 0.0


func to_dict() -> Dictionary:
	var pts_array: Array = []
	for p: Vector2 in points:
		pts_array.append({"x": p.x, "y": p.y})
	return {
		"layer": int(layer),
		"points": pts_array,
		"width": width,
		"time_cost_min": time_cost_min,
		"opacity_range": {"x": opacity_range.x, "y": opacity_range.y},
		"max_smudge": max_smudge,
	}


static func from_dict(data: Dictionary) -> MakeupGuide:
	var guide := MakeupGuide.new()
	guide.layer = data.get("layer", Enums.MakeupLayer.BASE) as Enums.MakeupLayer
	guide.width = float(data.get("width", 0.04))
	guide.time_cost_min = int(data.get("time_cost_min", 5))

	var op: Variant = data.get("opacity_range", {"x": 0.2, "y": 0.95})
	if op is Dictionary:
		guide.opacity_range = Vector2(float(op.get("x", 0.2)), float(op.get("y", 0.95)))
	elif op is Vector2:
		guide.opacity_range = op

	guide.max_smudge = float(data.get("max_smudge", 0.03))

	var raw_pts: Array = data.get("points", [])
	var pts := PackedVector2Array()
	for item: Variant in raw_pts:
		if item is Dictionary:
			pts.append(Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))))
		elif item is Vector2:
			pts.append(item)
	guide.points = pts
	return guide
