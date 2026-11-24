extends Node
## Автозагрузка: регистрирует все действия управления из GDD.
## Клавиши привязаны по ФИЗИЧЕСКОМУ положению — WASD работает и на русской раскладке.
## Если действие уже создано вручную в «Проект → Настройки → Список действий»,
## скрипт его не трогает: ручная настройка всегда важнее.

const KEY_ACTIONS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],          # взаимодействие / продолжить круг
	"draw_triquetra": [KEY_G],    # начертить Трикветру
	"swap_core": [KEY_R],         # смена призматического ядра
	"inventory": [KEY_TAB],
	"journal": [KEY_J],
	"map": [KEY_M],
}

const MOUSE_ACTIONS := {
	"attack": MOUSE_BUTTON_LEFT,          # ЛКМ — атака / использовать предмет в руке
	"charged_attack": MOUSE_BUTTON_RIGHT, # ПКМ — заряженная атака
}


func _enter_tree() -> void:
	# _enter_tree автозагрузки срабатывает раньше, чем _ready игрока
	for action: String in KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	for action: String in MOUSE_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, ev)
