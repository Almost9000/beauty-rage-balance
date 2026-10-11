extends GutTest

class MockState extends State:
	var enter_count: int = 0
	var exit_count: int = 0
	var update_count: int = 0
	var physics_update_count: int = 0
	var last_msg: Dictionary = {}

	func enter(msg: Dictionary = {}) -> void:
		enter_count += 1
		last_msg = msg

	func exit() -> void:
		exit_count += 1

	func update(_delta: float) -> void:
		update_count += 1

	func physics_update(_delta: float) -> void:
		physics_update_count += 1

func test_initial_state_and_registration() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"
	var walk: MockState = MockState.new()
	walk.name = "Walk"

	sm.add_child(idle)
	sm.add_child(walk)
	sm.initial_state = idle

	add_child_autoqfree(sm)

	assert_eq(sm.current_state, idle)
	assert_eq(idle.enter_count, 1)
	assert_eq(idle.state_machine, sm)
	assert_eq(walk.state_machine, sm)

func test_transition_to_with_message() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"
	var walk: MockState = MockState.new()
	walk.name = "Walk"

	sm.add_child(idle)
	sm.add_child(walk)
	sm.initial_state = idle
	add_child_autoqfree(sm)

	watch_signals(sm)

	var payload: Dictionary = {"speed": 4.5}
	sm.transition_to(&"Walk", payload)

	assert_eq(sm.current_state, walk)
	assert_eq(idle.exit_count, 1)
	assert_eq(walk.enter_count, 1)
	assert_eq(walk.last_msg, payload)
	assert_signal_emitted(sm, "state_changed")
	assert_signal_emitted_with_parameters(sm, "state_changed", [&"Idle", &"Walk"])

func test_transition_requested_by_child_state() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"
	var walk: MockState = MockState.new()
	walk.name = "Walk"

	sm.add_child(idle)
	sm.add_child(walk)
	sm.initial_state = idle
	add_child_autoqfree(sm)

	idle.transition_requested.emit(&"Walk", {"from_signal": true})

	assert_eq(sm.current_state, walk)
	assert_eq(walk.last_msg, {"from_signal": true})

func test_update_and_physics_update() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"
	var walk: MockState = MockState.new()
	walk.name = "Walk"

	sm.add_child(idle)
	sm.add_child(walk)
	sm.initial_state = idle
	add_child_autoqfree(sm)

	sm._process(0.016)
	sm._physics_process(0.016)

	assert_eq(idle.update_count, 1)
	assert_eq(idle.physics_update_count, 1)
	assert_eq(walk.update_count, 0)
	assert_eq(walk.physics_update_count, 0)

func test_transition_to_same_state_ignored() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"

	sm.add_child(idle)
	sm.initial_state = idle
	add_child_autoqfree(sm)

	assert_eq(idle.enter_count, 1)
	sm.transition_to(&"Idle")
	assert_eq(idle.enter_count, 1, "Should not re-enter already active state")
	assert_eq(idle.exit_count, 0)

func test_transition_to_unknown_state() -> void:
	var sm: StateMachine = StateMachine.new()
	var idle: MockState = MockState.new()
	idle.name = "Idle"

	sm.add_child(idle)
	sm.initial_state = idle
	add_child_autoqfree(sm)

	sm.transition_to(&"NonExistentState")
	assert_eq(sm.current_state, idle, "Current state should remain unchanged on invalid target")
