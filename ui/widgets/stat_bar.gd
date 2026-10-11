class_name StatBar
extends VBoxContainer

const STAT_COLORS: Dictionary = {
	Enums.Stat.SANITY: Color("#a78bfa"),   # Lavender / Lilac
	Enums.Stat.HEALTH: Color("#34d399"),   # Emerald / Mint
	Enums.Stat.HYGIENE: Color("#38bdf8"),  # Cyan / Sky Blue
	Enums.Stat.RAGE: Color("#f43f5e"),     # Crimson / Rose
}

const STAT_NAMES: Dictionary = {
	Enums.Stat.SANITY: "Sanity",
	Enums.Stat.HEALTH: "Health",
	Enums.Stat.HYGIENE: "Hygiene",
	Enums.Stat.RAGE: "Rage",
}

@export var stat_type: Enums.Stat = Enums.Stat.SANITY:
	set(val):
		stat_type = val
		if is_node_ready():
			_apply_stat_type()

@onready var stat_label: Label = $HeaderHBox/StatLabel
@onready var trend_label: Label = $HeaderHBox/TrendLabel
@onready var value_label: Label = $HeaderHBox/ValueLabel
@onready var progress_bar: ProgressBar = $ProgressBar

var _tween: Tween = null
var _current_value: float = 0.0
var _current_max: float = 100.0
var _current_rate: float = 0.0

func _ready() -> void:
	_apply_stat_type()

func set_stat_type(new_stat: Enums.Stat) -> void:
	stat_type = new_stat
	_apply_stat_type()

func set_value(new_val: float, max_val: float = 100.0, animate: bool = true) -> void:
	_current_max = max_val
	_current_value = clampf(new_val, 0.0, max_val)
	if progress_bar:
		progress_bar.max_value = max_val
		if animate and is_inside_tree():
			if _tween and _tween.is_valid():
				_tween.kill()
			_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(progress_bar, "value", _current_value, 0.35)
		else:
			if _tween and _tween.is_valid():
				_tween.kill()
			progress_bar.value = _current_value

	_update_labels()
	_update_tooltip()

func set_effective_rate(rate: float) -> void:
	_current_rate = rate
	if trend_label:
		if rate > 0.01:
			trend_label.text = "↑"
		elif rate < -0.01:
			trend_label.text = "↓"
		else:
			trend_label.text = "→"
	_update_tooltip()

func get_stat_value() -> float:
	return _current_value

func get_max_value() -> float:
	return _current_max

func get_effective_rate() -> float:
	return _current_rate

func get_trend_text() -> String:
	return trend_label.text if trend_label else ""

func _apply_stat_type() -> void:
	if not is_node_ready():
		return

	var name_key: String = STAT_NAMES.get(stat_type, "Unknown")
	stat_label.text = tr(name_key)

	var stat_color: Color = STAT_COLORS.get(stat_type, Color.WHITE)

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = stat_color
	fill_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.07, 0.10, 0.85)
	bg_style.border_color = Color(0.20, 0.22, 0.30, 0.55)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	_update_labels()
	_update_tooltip()

func _update_labels() -> void:
	if value_label:
		value_label.text = "%d / %d" % [roundi(_current_value), roundi(_current_max)]

func _update_tooltip() -> void:
	var name_str: String = tr(STAT_NAMES.get(stat_type, "Unknown"))
	tooltip_text = "%s: %.1f / %.1f (%+.2f/h)" % [name_str, _current_value, _current_max, _current_rate]
