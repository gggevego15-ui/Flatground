extends Control
## FlatGROUND's tactical, high-contrast main menu. Inspired by modern competitive FPS menus, without copying another game's branding.

const GAME_SCENE := "res://scenes/test_map.tscn"
var settings_open := false
var _settings_panel: PanelContainer
var _status_label: Label
var _quality_option: OptionButton
var _resolution_option: OptionButton
var _fullscreen_check: CheckBox
var _vsync_check: CheckBox
var _sensitivity_slider: HSlider
var _volume_slider: HSlider

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#10151a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Restrained diagonal light fields and a layered skyline create a bespoke backdrop.
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var diagonal := ColorRect.new()
	diagonal.color = Color("#18232a")
	diagonal.position = Vector2(420, 0)
	diagonal.size = Vector2(1000, 900)
	diagonal.rotation = deg_to_rad(13.0)
	diagonal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(diagonal)
	# Slow cinematic drift in the diagonal light field.
	var light_tween := create_tween().set_loops()
	light_tween.tween_property(diagonal, "rotation", deg_to_rad(9.0), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	light_tween.tween_property(diagonal, "rotation", deg_to_rad(13.0), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(15):
		var building := ColorRect.new()
		building.color = Color("#202a30") if i % 2 == 0 else Color("#1b242a")
		building.position = Vector2(440 + i * 92, 340 + (i % 4) * 42)
		building.size = Vector2(62 + (i % 3) * 22, 500 - (i % 4) * 38)
		building.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(building)
	var horizon := ColorRect.new()
	horizon.color = Color("#d7a45b")
	horizon.position = Vector2(360, 625)
	horizon.size = Vector2(1120, 2)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(horizon)
	horizon.modulate.a = 0.45
	var horizon_tween := create_tween().set_loops()
	horizon_tween.tween_property(horizon, "modulate:a", 0.95, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	horizon_tween.tween_property(horizon, "modulate:a", 0.45, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 44
	top.offset_top = 28
	top.offset_right = -44
	top.offset_bottom = 88
	top.add_theme_constant_override("separation", 18)
	add_child(top)
	var logo := Label.new()
	logo.text = "FG  /  FLATGROUND"
	logo.add_theme_font_size_override("font_size", 22)
	logo.add_theme_color_override("font_color", Color("#f0f1ed"))
	top.add_child(logo)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var version := Label.new()
	version.text = "MOVEMENT PROTOTYPE   •   BUILD 0.1"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color("#9ca7a9"))
	top.add_child(version)

	var left := VBoxContainer.new()
	left.position = Vector2(64, 128)
	left.size = Vector2(390, 600)
	left.add_theme_constant_override("separation", 12)
	add_child(left)
	var eyebrow := Label.new()
	eyebrow.text = "COMPETITIVE MOVEMENT  /  CITY OPERATIONS"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("#d7a45b"))
	left.add_child(eyebrow)
	var title := Label.new()
	title.text = "OWN THE\nMOMENTUM."
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#f3f3ed"))
	title.modulate.a = 0.0
	left.add_child(title)
	title.scale = Vector2(0.94, 0.94)
	title.pivot_offset = Vector2(190.0, 45.0)
	var title_tween := create_tween()
	title_tween.tween_interval(0.12)
	title_tween.tween_property(title, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_tween.parallel().tween_property(title, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var subtitle := Label.new()
	subtitle.text = "Build speed. Read the route.\nMaster every landing."
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#aeb8b8"))
	left.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	left.add_child(gap)
	_add_button(left, "DEPLOY  /  PLAY", _start_game, true)
	_add_button(left, "MOVEMENT TRAINING", _start_game, false)
	_add_button(left, "SETTINGS", _toggle_settings, false)
	_add_button(left, "QUIT TO DESKTOP", _quit_game, false)

	_settings_panel = PanelContainer.new()
	_settings_panel.position = Vector2(480, 100)
	_settings_panel.size = Vector2(380, 250)
	_settings_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#151d22")
	panel_style.border_color = Color("#d7a45b")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(20)
	_settings_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_settings_panel)
	_settings_panel.size = Vector2(430, 550)
	var settings_content := VBoxContainer.new()
	settings_content.add_theme_constant_override("separation", 8)
	_settings_panel.add_child(settings_content)
	var settings_title := Label.new()
	settings_title.text = "GRAPHICS  /  INPUT  /  AUDIO"
	settings_title.add_theme_font_size_override("font_size", 20)
	settings_content.add_child(settings_title)
	_add_setting_label(settings_content, "GRAPHICS QUALITY")
	_quality_option = OptionButton.new()
	for quality in ["Low", "Medium", "High", "Ultra 4K"]:
		_quality_option.add_item(quality)
	_quality_option.item_selected.connect(_on_quality_selected)
	settings_content.add_child(_quality_option)
	_add_setting_label(settings_content, "DISPLAY RESOLUTION")
	_resolution_option = OptionButton.new()
	for resolution_name in ["1920x1080", "2560x1440", "3840x2160"]:
		_resolution_option.add_item(resolution_name)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	settings_content.add_child(_resolution_option)
	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	settings_content.add_child(_fullscreen_check)
	_vsync_check = CheckBox.new()
	_vsync_check.text = "V-Sync"
	_vsync_check.toggled.connect(_on_vsync_toggled)
	settings_content.add_child(_vsync_check)
	_add_setting_label(settings_content, "MOUSE SENSITIVITY")
	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = 0.0003
	_sensitivity_slider.max_value = 0.006
	_sensitivity_slider.step = 0.0001
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	settings_content.add_child(_sensitivity_slider)
	_add_setting_label(settings_content, "MASTER VOLUME")
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value_changed.connect(_on_volume_changed)
	settings_content.add_child(_volume_slider)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 38
	close.pressed.connect(_toggle_settings)
	settings_content.add_child(close)
	_sync_settings_ui()

	_status_label = Label.new()
	_status_label.text = "READY  //  TRAINING DISTRICT AVAILABLE"
	_status_label.position = Vector2(64, 650)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color("#d7a45b"))
	add_child(_status_label)

	var footer := Label.new()
	footer.text = "FLATGROUND  ©  MOVEMENT IS A SKILL"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 44
	footer.offset_top = -42
	footer.offset_right = -44
	footer.offset_bottom = -14
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#879396"))
	add_child(footer)

func _add_button(parent: VBoxContainer, caption: String, action: Callable, primary := false) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(310, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#d7a45b") if primary else Color("#1b252b")
	normal.border_color = Color("#e6bd7c") if primary else Color("#35434a")
	normal.set_border_width_all(1)
	normal.set_content_margin_all(14)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#edbd70") if primary else Color("#29373e")
	hover.border_color = Color("#edbd70")
	hover.set_border_width_all(1)
	hover.set_content_margin_all(14)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("#11171a") if primary else Color("#e5e9e5"))
	button.add_theme_color_override("font_hover_color", Color("#11171a") if primary else Color("#ffffff"))
	button.pressed.connect(action)
	var button_index := parent.get_child_count()
	button.modulate.a = 0.0
	button.scale = Vector2(0.94, 0.94)
	button.pivot_offset = Vector2(155.0, 27.0)
	parent.add_child(button)
	var entrance := create_tween()
	entrance.tween_interval(0.18 + float(button_index) * 0.075)
	entrance.tween_property(button, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.parallel().tween_property(button, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button.mouse_entered.connect(_on_menu_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_menu_button_hover.bind(button, false))

func _on_menu_button_hover(button: Button, hovered: bool) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.025, 1.025) if hovered else Vector2.ONE, 0.14)

func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _toggle_settings() -> void:
	settings_open = not settings_open
	_settings_panel.visible = settings_open
	if settings_open:
		_sync_settings_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _status_label:
		_status_label.text = "SETTINGS OPEN  //  CHANGES SAVE AUTOMATICALLY" if settings_open else "READY  //  TRAINING DISTRICT AVAILABLE"

func _add_setting_label(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#d7a45b"))
	parent.add_child(label)

func _sync_settings_ui() -> void:
	var settings = get_node("/root/FlatSettings")
	_quality_option.select(maxi(0, ["Low", "Medium", "High", "Ultra 4K"].find(settings.graphics_quality)))
	_resolution_option.select(maxi(0, ["1920x1080", "2560x1440", "3840x2160"].find(settings.resolution)))
	_fullscreen_check.set_pressed_no_signal(settings.fullscreen)
	_vsync_check.set_pressed_no_signal(settings.vsync_enabled)
	_sensitivity_slider.set_value_no_signal(settings.mouse_sensitivity)
	_volume_slider.set_value_no_signal(settings.master_volume)

func _on_quality_selected(index: int) -> void:
	get_node("/root/FlatSettings").set_quality(_quality_option.get_item_text(index))
	_sync_settings_ui()

func _on_resolution_selected(index: int) -> void:
	get_node("/root/FlatSettings").set_resolution(_resolution_option.get_item_text(index))
	_sync_settings_ui()

func _on_fullscreen_toggled(value: bool) -> void:
	get_node("/root/FlatSettings").set_fullscreen(value)

func _on_vsync_toggled(value: bool) -> void:
	get_node("/root/FlatSettings").set_vsync(value)

func _on_sensitivity_changed(value: float) -> void:
	get_node("/root/FlatSettings").set_mouse_sensitivity(value)

func _on_volume_changed(value: float) -> void:
	get_node("/root/FlatSettings").set_master_volume(value)

func _quit_game() -> void:
	get_tree().quit()
