class_name OutingData
extends Resource

@export var id: StringName = &""
@export var type: Enums.OutingType = Enums.OutingType.GIRLS_DAY_OUT
@export var display_name: String = ""
@export var prep_window_min: int = 90
@export var late_grace_min: int = 30
@export var duration_min: int = 180
@export var cost_cents: int = 0
@export var checks: Array[PrepCheck] = []
@export_range(0.0, 1.0, 0.01) var pass_threshold: float = 0.75
@export_range(0.0, 1.0, 0.01) var partial_threshold: float = 0.4
@export var late_penalty_per_10_min: float = 0.1

@export var pass_modifiers: Array[StatModifier] = []
@export var partial_modifiers: Array[StatModifier] = []
@export var fail_modifiers: Array[StatModifier] = []

@export var pass_affinity_delta: int = 15
@export var partial_affinity_delta: int = 5
@export var fail_affinity_delta: int = -10

## Optional dictionary overrides: Enums.OutingResult or "pass"/"partial"/"fail" -> Array[StatModifier]
@export var modifiers: Dictionary = {}
## Optional dictionary overrides: Enums.OutingResult or "pass"/"partial"/"fail" -> int
@export var affinity_delta: Dictionary = {}


func get_affinity_delta(result: Enums.OutingResult) -> int:
	if affinity_delta.has(result):
		return int(affinity_delta[result])
	if affinity_delta.has(int(result)):
		return int(affinity_delta[int(result)])

	var key: String = ""
	match result:
		Enums.OutingResult.PASS: key = "pass"
		Enums.OutingResult.PARTIAL: key = "partial"
		Enums.OutingResult.FAIL: key = "fail"

	if affinity_delta.has(key):
		return int(affinity_delta[key])

	match result:
		Enums.OutingResult.PASS: return pass_affinity_delta
		Enums.OutingResult.PARTIAL: return partial_affinity_delta
		Enums.OutingResult.FAIL: return fail_affinity_delta

	return 0


func get_modifiers_for_result(result: Enums.OutingResult) -> Array[StatModifier]:
	if modifiers.has(result):
		var raw: Variant = modifiers[result]
		if raw is Array:
			var res_arr: Array[StatModifier] = []
			for m: Variant in (raw as Array):
				if m is StatModifier:
					res_arr.append(m)
			return res_arr
	if modifiers.has(int(result)):
		var raw: Variant = modifiers[int(result)]
		if raw is Array:
			var res_arr: Array[StatModifier] = []
			for m: Variant in (raw as Array):
				if m is StatModifier:
					res_arr.append(m)
			return res_arr

	var key: String = ""
	match result:
		Enums.OutingResult.PASS: key = "pass"
		Enums.OutingResult.PARTIAL: key = "partial"
		Enums.OutingResult.FAIL: key = "fail"

	if modifiers.has(key):
		var raw: Variant = modifiers[key]
		if raw is Array:
			var res_arr: Array[StatModifier] = []
			for m: Variant in (raw as Array):
				if m is StatModifier:
					res_arr.append(m)
			return res_arr

	match result:
		Enums.OutingResult.PASS: return pass_modifiers
		Enums.OutingResult.PARTIAL: return partial_modifiers
		Enums.OutingResult.FAIL: return fail_modifiers

	return []


func evaluate_readiness() -> Dictionary:
	var checklist: Array[Dictionary] = []
	var total_weight: float = 0.0
	var weighted_score: float = 0.0

	for check: PrepCheck in checks:
		if check == null:
			continue
		var s: float = check.evaluate()
		var w: float = check.weight
		var p: bool = check.is_passed(s)
		checklist.append({
			"label": check.label,
			"score": s,
			"passed": p,
			"weight": w,
		})
		weighted_score += s * w
		total_weight += w

	var final_score: float = (weighted_score / total_weight) if total_weight > 0.0 else 1.0
	var res: Enums.OutingResult = Enums.OutingResult.FAIL
	if final_score >= pass_threshold:
		res = Enums.OutingResult.PASS
	elif final_score >= partial_threshold:
		res = Enums.OutingResult.PARTIAL

	return {
		"score": final_score,
		"result": res,
		"checklist": checklist,
	}
