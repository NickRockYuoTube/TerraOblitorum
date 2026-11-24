extends Node
class_name Health
## Компонент здоровья. Вешается дочерним узлом «Health» на игрока
## (позже — и на врагов). Сам ничего не рисует, только считает и шлёт сигналы.
##
## Состояния по GDD (при 120 HP):
##   Норма      81–120
##   Осторожно  41–80
##   Опасность   1–40

signal health_changed(current: int, max_health: int)
signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal state_changed(new_state: State)
signal died

enum State { NORMAL, CAUTION, DANGER, DEAD }

@export var max_health := 120
@export var caution_below := 81    ## здоровье НИЖЕ этого числа — «Осторожно»
@export var danger_below := 41     ## здоровье НИЖЕ этого числа — «Опасность»
@export var invulnerable := false  ## бессмертие для отладки

var current := -1
var state: State = State.NORMAL


func _ready() -> void:
	if current < 0:
		current = max_health
	state = _calc_state()


## Нанести урон. source — кто ударил (пригодится врагам и звукам).
func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or invulnerable or is_dead():
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount, source)
	_apply_change()


## Вылечить. Возвращает, сколько реально восстановлено (0, если здоровье полное).
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var old := current
	current = mini(current + amount, max_health)
	var restored := current - old
	if restored > 0:
		healed.emit(restored)
		_apply_change()
	return restored


## Лечение в долях от максимума: heal_percent(0.2) = 24 при 120 HP (жидкость из GDD).
func heal_percent(fraction: float) -> int:
	return heal(roundi(max_health * fraction))


func is_dead() -> bool:
	return state == State.DEAD


func is_full() -> bool:
	return current >= max_health


## Сначала обновляем состояние, потом шлём сигналы — чтобы все слушатели видели актуальные данные.
func _apply_change() -> void:
	var old_state := state
	state = _calc_state()
	health_changed.emit(current, max_health)
	if state != old_state:
		state_changed.emit(state)
		if state == State.DEAD:
			died.emit()


func _calc_state() -> State:
	if current <= 0:
		return State.DEAD
	elif current < danger_below:
		return State.DANGER
	elif current < caution_below:
		return State.CAUTION
	return State.NORMAL


static func state_name(s: State) -> String:
	match s:
		State.NORMAL: return "Норма"
		State.CAUTION: return "Осторожно"
		State.DANGER: return "Опасность"
		_: return "Мёртв"
