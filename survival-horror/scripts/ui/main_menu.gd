# res://scripts/ui/main_menu.gd
extends Control
class_name MainMenu
## Главное меню. Строится кодом: достаточно узла Control с этим скриптом.

@export_file("*.tscn") var first_level: String = ""   ## уровень для «Новой игры»
@export var game_title: String = "SURVIVAL HORROR"
@export var background_color: Color = Color(0.03, 0.03, 0.04)
@export var background_texture: Texture2D             ## необязательная картинка на фон
@export var menu_theme: Theme                         ## шрифты и стиль кнопок

var _main: VBoxContainer
var _load: LoadPanel
var _settings: SettingsPanel
var _continue_button: Button
var _load_button: Button


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if menu_theme:
		theme = menu_theme
	_build()
	_show("main")


func _build() -> void:
	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	if background_texture:
		var picture := TextureRect.new()
		picture.texture = background_texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(picture)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 32)
	center.add_child(root)

	var title := Label.new()
	title.text = game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	root.add_child(title)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	root.add_child(_main)
	_continue_button = _add_button("Продолжить", _on_continue_pressed)
	_add_button("Новая игра", _on_new_game_pressed)
	_load_button = _add_button("Загрузить", _show.bind("load"))
	_add_button("Настройки", _show.bind("settings"))
	_add_button("Выход", _on_quit_pressed)

	_load = LoadPanel.new()
	_load.back_pressed.connect(_show.bind("main"))
	root.add_child(_load)

	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(_show.bind("main"))
	root.add_child(_settings)


func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	_main.add_child(button)
	return button


func _show(panel: String) -> void:
	_main.visible = panel == "main"
	_load.visible = panel == "load"
	_settings.visible = panel == "settings"
	match panel:
		"main":
			var has_save := SaveManager.has_any_save()
			_continue_button.disabled = not has_save
			_load_button.disabled = not has_save
			if has_save:
				_continue_button.grab_focus()
			else:
				(_main.get_child(1) as Button).grab_focus()
		"load":
			_load.refresh()
			_load.focus_first.call_deferred()
		"settings":
			_settings.refresh()
			_settings.focus_first.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# Esc в подменю возвращает в главное
	if event.is_action_pressed("ui_cancel") and not _main.visible:
		Settings.save_settings()
		_show("main")
		get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	var slot := SaveManager.get_latest_slot()
	if slot >= 0:
		SaveManager.load_game(slot)


func _on_new_game_pressed() -> void:
	if first_level == "":
		push_error("MainMenu: не указан First Level (уровень для новой игры)")
		return
	SaveManager.new_game(first_level)


func _on_quit_pressed() -> void:
	get_tree().quit()
