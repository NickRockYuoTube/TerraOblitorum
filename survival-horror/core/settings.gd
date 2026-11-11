# res://core/settings.gd
extends Node
## Настройки игры. Добавлены в Autoload под именем Settings.
## Хранятся в user://settings.cfg и применяются сразу.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity: float = 0.002
var fov: float = 75.0
var master_volume: float = 1.0
var head_bob: bool = true
var fullscreen: bool = false
var vsync: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()
	# Новый игрок или его камера сразу получают текущие настройки
	get_tree().node_added.connect(_on_node_added)


## Изменить настройку по имени и сразу применить
func set_setting(setting_name: String, value: Variant) -> void:
	set(setting_name, value)
	apply_all()
	changed.emit()


func apply_all() -> void:
	# Звук
	var bus_volume := linear_to_db(maxf(master_volume, 0.0001))
	AudioServer.set_bus_volume_db(0, bus_volume)
	AudioServer.set_bus_mute(0, master_volume <= 0.0)

	# Окно
	var wanted_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var current_mode := DisplayServer.window_get_mode()
	var is_full := current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		DisplayServer.window_set_mode(wanted_mode)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	# Игрок, если он сейчас в игре
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		_apply_to_player(player)
		player.camera.fov = fov
		var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
		if manager:
			manager._default_fov = fov


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("video", "fov", fov)
	config.set_value("video", "head_bob", head_bob)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("audio", "master_volume", master_volume)
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	fov = config.get_value("video", "fov", fov)
	head_bob = config.get_value("video", "head_bob", head_bob)
	fullscreen = config.get_value("video", "fullscreen", fullscreen)
	vsync = config.get_value("video", "vsync", vsync)
	master_volume = config.get_value("audio", "master_volume", master_volume)


func _on_node_added(node: Node) -> void:
	if node is Player:
		_apply_to_player(node as Player)
	elif node is Camera3D and node.owner is Player:
		(node as Camera3D).fov = fov


func _apply_to_player(player: Player) -> void:
	player.mouse_sensitivity = mouse_sensitivity
	player.bob_enabled = head_bob
