extends GutTest

func before_each() -> void:
	SceneRouter.reset_state()

func after_each() -> void:
	SceneRouter.reset_state()

func test_store_and_get_level_state() -> void:
	var state_data: Dictionary = {
		"clutter_items": ["mug", "sock"],
		"cleanliness_score": 75,
		"plants_watered": true
	}
	SceneRouter.store_level_state("apartment", state_data)

	var retrieved: Dictionary = SceneRouter.get_level_state("apartment")
	assert_eq(retrieved["clutter_items"], ["mug", "sock"])
	assert_eq(retrieved["cleanliness_score"], 75)
	assert_eq(retrieved["plants_watered"], true)

func test_get_unknown_level_state_returns_empty_dict() -> void:
	var retrieved: Dictionary = SceneRouter.get_level_state("non_existent_level")
	assert_true(retrieved.is_empty())

func test_state_mutation_isolation() -> void:
	var original: Dictionary = {"count": 1}
	SceneRouter.store_level_state("apartment", original)

	var copy1: Dictionary = SceneRouter.get_level_state("apartment")
	copy1["count"] = 999

	var copy2: Dictionary = SceneRouter.get_level_state("apartment")
	assert_eq(copy2["count"], 1, "Modifying retrieved dictionary should not mutate internal store")

func test_consume_spawn_id() -> void:
	assert_eq(SceneRouter.consume_spawn_id(), &"default", "Default spawn ID should be 'default'")
	assert_eq(SceneRouter.consume_spawn_id(), &"default", "Subsequent calls should still return 'default'")

func test_reset_state() -> void:
	SceneRouter.store_level_state("apartment", {"active": true})
	SceneRouter.current_level_id = "apartment"

	SceneRouter.reset_state()

	assert_eq(SceneRouter.current_level_id, "")
	assert_true(SceneRouter.get_level_state("apartment").is_empty())
	assert_eq(SceneRouter.consume_spawn_id(), &"default")

func test_to_dict_and_from_dict_json_round_trip() -> void:
	SceneRouter.current_level_id = "apartment"
	SceneRouter.store_level_state("apartment", {
		"clutter_count": 4,
		"dishes_dirty": true,
		"room_temperature": 21.5
	})
	SceneRouter.store_level_state("thrift_store", {
		"visited_today": false,
		"restock_day": 3
	})

	var dict: Dictionary = SceneRouter.to_dict()
	assert_eq(dict["current_level_id"], "apartment")
	assert_true(dict.has("level_states"))

	# Test JSON stringify and parse
	var json_string: String = JSON.stringify(dict)
	assert_gt(json_string.length(), 0)

	var parsed: Variant = JSON.parse_string(json_string)
	assert_not_null(parsed)
	assert_true(parsed is Dictionary)

	# Reset and restore
	SceneRouter.reset_state()
	assert_eq(SceneRouter.current_level_id, "")
	assert_true(SceneRouter.get_level_state("apartment").is_empty())

	SceneRouter.from_dict(parsed as Dictionary)

	assert_eq(SceneRouter.current_level_id, "apartment")
	var apt_state: Dictionary = SceneRouter.get_level_state("apartment")
	assert_eq(int(apt_state["clutter_count"]), 4)
	assert_eq(apt_state["dishes_dirty"], true)
	assert_almost_eq(float(apt_state["room_temperature"]), 21.5, 0.0001)

	var thrift_state: Dictionary = SceneRouter.get_level_state("thrift_store")
	assert_eq(thrift_state["visited_today"], false)
	assert_eq(int(thrift_state["restock_day"]), 3)
