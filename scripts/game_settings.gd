extends Node
## Persistent graphics, mouse and audio settings for FlatGROUND.

const SAVE_PATH := "user://flatground_settings.cfg"
var config := ConfigFile.new()
var graphics_quality := "Ultra 4K"
var resolution := "3840x2160"
var fullscreen := true
var mouse_sensitivity := 0.0018
var master_volume := 0.85
var vsync_enabled := true

func _ready() -> void:
	if config.load(SAVE_PATH) == OK:
		graphics_quality = str(config.get_value("graphics", "quality", graphics_quality))
		resolution = str(config.get_value("graphics", "resolution", resolution))
		fullscreen = bool(config.get_value("graphics", "fullscreen", fullscreen))
		vsync_enabled = bool(config.get_value("graphics", "vsync", vsync_enabled))
		mouse_sensitivity = float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
		master_volume = float(config.get_value("audio", "master_volume", master_volume))
	apply_graphics()
	apply_audio()

func apply_graphics() -> void:
	var viewport := get_viewport()
	match graphics_quality:
		"Low":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_scale = 0.75
		"Medium":
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_scale = 0.85
		"High":
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_scale = 1.0
		_:
			viewport.msaa_3d = Viewport.MSAA_8X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.scaling_3d_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(_resolution_size())

func _resolution_size() -> Vector2i:
	match resolution:
		"3840x2160": return Vector2i(3840, 2160)
		"2560x1440": return Vector2i(2560, 1440)
		_: return Vector2i(1920, 1080)

func apply_audio() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(master_volume, 0.001)))

func save_settings() -> void:
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "resolution", resolution)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync_enabled)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SAVE_PATH)

func set_quality(value: String) -> void:
	graphics_quality = value
	if value == "Ultra 4K":
		resolution = "3840x2160"
	apply_graphics()
	save_settings()

func set_resolution(value: String) -> void:
	resolution = value
	if value == "3840x2160":
		graphics_quality = "Ultra 4K"
	apply_graphics()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_graphics()
	save_settings()

func set_vsync(value: bool) -> void:
	vsync_enabled = value
	apply_graphics()
	save_settings()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0003, 0.006)
	save_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()
