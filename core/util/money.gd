class_name Money
extends RefCounted

const MINUS_SIGN: String = "−" # U+2212
const CURRENCY_SYMBOL: String = "€"

static func format(cents: int) -> String:
	var is_negative: bool = cents < 0
	var abs_cents: int = absi(cents)
	var whole: int = abs_cents / 100
	var remainder: int = abs_cents % 100

	var whole_str: String = _format_thousands(whole)
	var remainder_str: String = "%02d" % remainder

	if is_negative:
		return "%s%s%s.%s" % [MINUS_SIGN, CURRENCY_SYMBOL, whole_str, remainder_str]
	return "%s%s.%s" % [CURRENCY_SYMBOL, whole_str, remainder_str]


static func format_cents(cents: int) -> String:
	return format(cents)


static func _format_thousands(n: int) -> String:
	var s: String = str(n)
	var length: int = s.length()
	if length <= 3:
		return s
	var res: String = ""
	var count: int = 0
	for i: int in range(length - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
