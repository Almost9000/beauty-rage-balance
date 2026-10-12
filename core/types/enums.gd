class_name Enums

# IMPORTANT: Enum values are append-only.
# .tres resource files and save games store enum values as integer values.
# Inserting, deleting, or reordering enum members will silently corrupt existing
# content and save files. Always add new values at the end of each enum.

enum Stat {
	SANITY,
	HEALTH,
	HYGIENE,
	RAGE,
}

enum ModifierKind {
	INSTANT,
	RATE_ADD,
	RATE_MUL,
	CAP,
}

enum CyclePhase {
	MENSTRUAL,
	FOLLICULAR,
	OVULATORY,
	LUTEAL,
}

enum Slot {
	TOP,
	BOTTOM,
	DRESS,
	OUTERWEAR,
	SHOES,
	ACCESSORY,
}

enum Stance {
	PLACATE,
	DEFLECT,
	ASSERT,
}

enum OutingType {
	GIRLS_DAY_OUT,
	DATE_NIGHT,
}

enum OutingResult {
	PASS,
	PARTIAL,
	FAIL,
}

enum MakeupLayer {
	BASE,
	BLUSH,
	EYESHADOW,
	EYELINER,
	LIPSTICK,
}
