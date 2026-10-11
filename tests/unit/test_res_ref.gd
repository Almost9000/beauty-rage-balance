extends GutTest

const FIXTURE_WITH_UID_PATH: String = "res://tests/fixtures/fixture_with_uid.tres"
const FIXTURE_NO_UID_PATH: String = "res://tests/fixtures/fixture_no_uid.tres"

func test_round_trip_with_uid() -> void:
	var res: Resource = load(FIXTURE_WITH_UID_PATH)
	assert_not_null(res, "Fixture with UID must load")

	var ref_str: String = ResRef.to_ref(res)
	assert_true(ref_str.begins_with("uid://"), "Reference must be a uid:// string: " + ref_str)

	var loaded: Resource = ResRef.load_ref(ref_str)
	assert_not_null(loaded, "load_ref must resolve uid:// string")
	assert_true(loaded is FixtureItem, "Loaded resource must be FixtureItem")
	var fixture_item: FixtureItem = loaded as FixtureItem
	assert_eq(fixture_item.title, "Fixture With UID")

func test_fallback_to_path_when_no_uid() -> void:
	var res: Resource = load(FIXTURE_NO_UID_PATH)
	assert_not_null(res, "Fixture without UID must load")

	var ref_str: String = ResRef.to_ref(res)
	assert_eq(ref_str, FIXTURE_NO_UID_PATH, "Must fall back to res:// path when resource lacks UID")

	var loaded: Resource = ResRef.load_ref(ref_str)
	assert_not_null(loaded, "load_ref must resolve res:// path")
	assert_true(loaded is FixtureItem, "Loaded resource must be FixtureItem")
	var fixture_item: FixtureItem = loaded as FixtureItem
	assert_eq(fixture_item.title, "Fixture Without UID")

func test_edge_cases() -> void:
	assert_eq(ResRef.to_ref(null), "", "Null resource yields empty string")

	var in_memory: Resource = Resource.new()
	assert_eq(ResRef.to_ref(in_memory), "", "In-memory unsaved resource yields empty string")

	assert_null(ResRef.load_ref(""), "Empty reference yields null")
	assert_null(ResRef.load_ref("uid://invalidnonexistent"), "Invalid UID yields null")
	assert_null(ResRef.load_ref("res://does_not_exist.tres"), "Invalid path yields null")
