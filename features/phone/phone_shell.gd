class_name PhoneShell
extends CanvasLayer

signal opened()
signal closed()
signal app_opened(app_id: StringName)
signal app_closed(app_id: StringName)

@export var app_scenes: Array[PackedScene] = []
@export var animation_duration: float = 0.25

var is_open: bool = false
var current_app_id: StringName = &""

@onready var notification_banner: NotificationBanner = $NotificationBanner
@onready var slide_container: Control = $PhoneSlideContainer
@onready var aspect_ratio_container: AspectRatioContainer = $PhoneSlideContainer/MarginContainer/AspectRatioContainer
@onready var status_bar_time: Label = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/StatusBar/HBox/TimeLabel
@onready var home_screen: HomeScreen = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/ScreenContent/HomeScreen
@onready var app_container: Control = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/ScreenContent/AppContainer
@onready var nav_back_btn: Button = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/NavigationBar/NavBackBtn
@onready var nav_home_btn: Button = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/NavigationBar/NavHomeBtn
@onready var nav_close_btn: Button = $PhoneSlideContainer/MarginContainer/AspectRatioContainer/PhoneBezel/InnerMargin/ScreenPanel/ScreenVBox/NavigationBar/NavCloseBtn

var _installed_apps: Dictionary = {}  # app_id (StringName) -> AppBase
var _slide_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50

	# Ensure action exists defensively
	if not InputMap.has_action("phone_toggle"):
		InputMap.add_action("phone_toggle")
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("phone_toggle", key_event)
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("phone_toggle", joy_event)

	if nav_back_btn:
		nav_back_btn.pressed.connect(handle_back)
	if nav_home_btn:
		nav_home_btn.pressed.connect(close_current_app)
	if nav_close_btn:
		nav_close_btn.pressed.connect(func() -> void: close())

	if home_screen:
		home_screen.app_selected.connect(_on_home_app_selected)

	if notification_banner:
		notification_banner.notification_clicked.connect(_on_notification_clicked)

	_setup_apps()
	_update_status_bar()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("minute_ticked"):
		if not clock.minute_ticked.is_connected(_on_clock_minute_ticked):
			clock.minute_ticked.connect(_on_clock_minute_ticked)

	if slide_container:
		slide_container.visible = false
		slide_container.position.y = _get_offscreen_y()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_toggle"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()
		return


func _setup_apps() -> void:
	# Load configured app scenes
	for scene: PackedScene in app_scenes:
		if scene:
			var app: AppBase = scene.instantiate() as AppBase
			if app:
				register_app(app)

	# If calendar app wasn't loaded from app_scenes, load default calendar
	if not _installed_apps.has(&"calendar"):
		var cal_path := "res://features/phone/apps/calendar/calendar_app.tscn"
		if ResourceLoader.exists(cal_path):
			var cal_scene: PackedScene = load(cal_path) as PackedScene
			if cal_scene:
				var cal: AppBase = cal_scene.instantiate() as AppBase
				if cal:
					register_app(cal)

	# If dating app wasn't loaded from app_scenes, load default dating app
	if not _installed_apps.has(&"dating"):
		var dating_path := "res://features/phone/apps/dating/dating_app.tscn"
		if ResourceLoader.exists(dating_path):
			var dating_scene: PackedScene = load(dating_path) as PackedScene
			if dating_scene:
				var dating: AppBase = dating_scene.instantiate() as AppBase
				if dating:
					register_app(dating)

	_refresh_home_screen()


func register_app(app: AppBase) -> void:
	if app == null:
		return
	if app.app_id.is_empty():
		push_warning("PhoneShell: Cannot register app with empty app_id")
		return

	if _installed_apps.has(app.app_id):
		var old_app: AppBase = _installed_apps[app.app_id]
		if old_app != app:
			if old_app.get_parent():
				old_app.get_parent().remove_child(old_app)
			old_app.queue_free()

	_installed_apps[app.app_id] = app
	if app_container and app.get_parent() != app_container:
		app_container.add_child(app)

	app.close()

	if not app.notification_posted.is_connected(_on_app_notification_posted):
		app.notification_posted.connect(_on_app_notification_posted)

	_refresh_home_screen()


func register_app_scene(scene: PackedScene) -> AppBase:
	if scene == null:
		return null
	var inst: AppBase = scene.instantiate() as AppBase
	if inst:
		register_app(inst)
	return inst


func get_app(app_id: StringName) -> AppBase:
	return _installed_apps.get(app_id, null) as AppBase


func get_installed_apps() -> Array[AppBase]:
	var apps: Array[AppBase] = []
	for id: StringName in _installed_apps:
		apps.append(_installed_apps[id] as AppBase)
	return apps


func _refresh_home_screen() -> void:
	if home_screen:
		home_screen.populate_apps(get_installed_apps())


func open(immediate: bool = false) -> void:
	if is_open:
		return

	is_open = true
	_kill_slide_tween()

	_update_status_bar()
	if slide_container:
		slide_container.visible = true

		if immediate or animation_duration <= 0.0:
			slide_container.position.y = 0.0
			opened.emit()
		else:
			slide_container.position.y = _get_offscreen_y()
			_slide_tween = create_tween()
			_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_slide_tween.tween_property(slide_container, "position:y", 0.0, animation_duration)
			opened.emit()
	else:
		opened.emit()


func close(immediate: bool = false) -> void:
	if not is_open:
		return

	is_open = false
	_kill_slide_tween()

	var offscreen_y: float = _get_offscreen_y()
	if slide_container:
		if immediate or animation_duration <= 0.0:
			slide_container.position.y = offscreen_y
			slide_container.visible = false
			closed.emit()
		else:
			_slide_tween = create_tween()
			_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_slide_tween.tween_property(slide_container, "position:y", offscreen_y, animation_duration)
			_slide_tween.finished.connect(_on_close_tween_finished)
	else:
		closed.emit()


func _on_close_tween_finished() -> void:
	if not is_open and slide_container:
		slide_container.visible = false
	closed.emit()


func toggle(immediate: bool = false) -> void:
	if is_open:
		close(immediate)
	else:
		open(immediate)


func open_app(app_id: StringName) -> bool:
	if not _installed_apps.has(app_id):
		return false

	if not is_open:
		open(false)

	if current_app_id != &"" and current_app_id != app_id:
		var active: AppBase = _installed_apps.get(current_app_id, null) as AppBase
		if active:
			active.close()
			app_closed.emit(current_app_id)

	if home_screen:
		home_screen.hide()

	current_app_id = app_id
	var app: AppBase = _installed_apps[app_id] as AppBase
	app.open()
	app_opened.emit(app_id)
	return true


func close_current_app() -> void:
	if current_app_id == &"":
		return

	var app: AppBase = _installed_apps.get(current_app_id, null) as AppBase
	if app:
		app.close()
		app_closed.emit(current_app_id)

	current_app_id = &""

	if home_screen:
		home_screen.show()


func handle_back() -> void:
	if current_app_id != &"":
		var app: AppBase = _installed_apps.get(current_app_id, null) as AppBase
		if app:
			var handled: bool = app.handle_back()
			if not handled:
				close_current_app()
	else:
		close()


func post_notification(title: String, body: String, app_id: StringName = &"") -> void:
	if notification_banner:
		notification_banner.queue_notification(title, body, app_id)


func _on_app_notification_posted(title: String, body: String, app_id: StringName) -> void:
	post_notification(title, body, app_id)


func _on_home_app_selected(app_id: StringName) -> void:
	open_app(app_id)


func _on_notification_clicked(app_id: StringName) -> void:
	if not app_id.is_empty() and _installed_apps.has(app_id):
		open_app(app_id)
	else:
		open()


func _on_clock_minute_ticked(_minute: int) -> void:
	_update_status_bar()


func _update_status_bar() -> void:
	if not status_bar_time:
		return
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("format_time"):
		status_bar_time.text = str(clock.call("format_time"))
	else:
		status_bar_time.text = "07:00"


func _get_offscreen_y() -> float:
	var vp := get_viewport()
	if vp:
		return vp.get_visible_rect().size.y + 100.0
	return 1180.0


func _kill_slide_tween() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
		_slide_tween = null


func reset_state() -> void:
	close(true)
	close_current_app()
	if notification_banner:
		notification_banner.clear_queue()
	for id: StringName in _installed_apps:
		var app: AppBase = _installed_apps[id]
		if app.has_method("reset_state"):
			app.reset_state()


func to_dict() -> Dictionary:
	var apps_data: Dictionary = {}
	for id: StringName in _installed_apps:
		var app: AppBase = _installed_apps[id]
		if app.has_method("to_dict"):
			var d: Dictionary = app.to_dict()
			if not d.is_empty():
				apps_data[str(id)] = d

	return {
		"is_open": is_open,
		"current_app_id": str(current_app_id),
		"apps": apps_data,
	}


func from_dict(data: Dictionary) -> void:
	if data.has("apps") and data["apps"] is Dictionary:
		var apps_data: Dictionary = data["apps"]
		for key: String in apps_data:
			var id: StringName = StringName(key)
			if _installed_apps.has(id):
				var app: AppBase = _installed_apps[id]
				if app.has_method("from_dict"):
					app.from_dict(apps_data[key] as Dictionary)

	var target_app: String = str(data.get("current_app_id", ""))
	if not target_app.is_empty() and _installed_apps.has(StringName(target_app)):
		open_app(StringName(target_app))
	else:
		close_current_app()

	if bool(data.get("is_open", false)):
		open(true)
	else:
		close(true)
