# res://scripts/ui/pause_menu.gd
extends Control
class_name PauseMenu
## Меню паузы на Esc. Строится кодом: достаточно узла Control с этим скриптом в HUD.

@export_file("*.tscn") var main_menu_scene: String = ""
@export var menu_theme: Theme
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.75)

var is_open: bool = false
var _main: VBoxContainer
var _load: LoadPanel
var _settings: SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if menu_theme:
		theme = menu_theme
	_build()
	hide()


func _build() -> void:
	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	center.add_child(root)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	root.add_child(_main)

	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	_main.add_child(title)

	_add_button("Продолжить", close)
	_add_button("Загрузить", _show.bind("load"))
	_add_button("Настройки", _show.bind("settings"))
	_add_button("Главное меню", _on_main_menu_pressed)
	_add_button("Выход", _on_quit_pressed)

	_load = LoadPanel.new()
	_load.back_pressed.connect(_show.bind("main"))
	root.add_child(_load)

	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(_show.bind("main"))
	root.add_child(_settings)


func _add_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	_main.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_open:
		# Из подменю — назад, из главного — закрыть паузу
		if _main.visible:
			close()
		else:
			Settings.save_settings()
			_show("main")
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and not _player_is_dead():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	show()
	_show("main")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	Settings.save_settings()
	is_open = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show(panel: String) -> void:
	_main.visible = panel == "main"
	_load.visible = panel == "load"
	_settings.visible = panel == "settings"
	match panel:
		"main":
			(_main.get_child(1) as Button).grab_focus()
		"load":
			_load.refresh()
			_load.focus_first.call_deferred()
		"settings":
			_settings.refresh()
			_settings.focus_first.call_deferred()


func _player_is_dead() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	return player != null and player.is_dead


func _on_main_menu_pressed() -> void:
	if main_menu_scene == "":
		push_error("PauseMenu: не указана Main Menu Scene")
		return
	is_open = false
	SaveManager.go_to(main_menu_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
