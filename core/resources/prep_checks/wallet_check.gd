class_name WalletCheck
extends PrepCheck

@export var cost_cents: int = 0


func _init() -> void:
	label = "Funds"
	weight = 1.0
	pass_threshold = 1.0


func evaluate() -> float:
	if cost_cents <= 0:
		return 1.0

	var fm: Node = null
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		fm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("FinanceManager")
	if fm == null:
		fm = FinanceManager

	if fm == null:
		return 0.0

	var wallet: int = int(fm.get("wallet_cents")) if "wallet_cents" in fm else 0
	if wallet >= cost_cents:
		return 1.0
	if wallet <= 0:
		return 0.0
	return clampf(float(wallet) / float(cost_cents), 0.0, 1.0)
