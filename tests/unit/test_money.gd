extends GutTest

func test_money_format_positive() -> void:
	assert_eq(Money.format(0), "€0.00")
	assert_eq(Money.format(1), "€0.01")
	assert_eq(Money.format(9), "€0.09")
	assert_eq(Money.format(10), "€0.10")
	assert_eq(Money.format(99), "€0.99")
	assert_eq(Money.format(100), "€1.00")
	assert_eq(Money.format(1299), "€12.99")
	assert_eq(Money.format(99999), "€999.99")
	assert_eq(Money.format(100000), "€1,000.00")
	assert_eq(Money.format(123456), "€1,234.56")
	assert_eq(Money.format(1000000), "€10,000.00")
	assert_eq(Money.format(100000000), "€1,000,000.00")
	assert_eq(Money.format(123456789), "€1,234,567.89")

func test_money_format_negative() -> void:
	assert_eq(Money.format(-1), "−€0.01")
	assert_eq(Money.format(-9), "−€0.09")
	assert_eq(Money.format(-10), "−€0.10")
	assert_eq(Money.format(-99), "−€0.99")
	assert_eq(Money.format(-100), "−€1.00")
	assert_eq(Money.format(-300), "−€3.00")
	assert_eq(Money.format(-123456), "−€1,234.56")
	assert_eq(Money.format(-100000000), "−€1,000,000.00")
	assert_eq(Money.format(-123456789), "−€1,234,567.89")

func test_money_format_uses_unicode_minus() -> void:
	var formatted: String = Money.format(-500)
	assert_true(formatted.begins_with("−€"), "Should start with unicode minus and euro symbol")
	assert_eq(formatted.unicode_at(0), 0x2212, "First char must be U+2212 MINUS SIGN")

func test_no_floats_in_format() -> void:
	# Ensure integer type input produces valid formatted strings without type coercion to float
	var max_cents: int = 999999999
	var s: String = Money.format(max_cents)
	assert_eq(s, "€9,999,999.99")
