extends Node
class_name Health
## Компонент здоровья. Подходит и игроку, и врагам, и разрушаемым объектам.

signal health_changed(current: float, max_value: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
@export var invulnerability_time: float = 0.5  ## неуязвимость после удара (сек)

var current: float
var is_dead: bool = false
var _invulnerable_timer: float = 0.0


func _ready() -> void:
	current = max_health
	# Отложенно, чтобы все слушатели успели подключиться
	call_deferred("_emit_changed")


func _physics_process(delta: float) -> void:
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0 or _invulnerable_timer > 0.0:
		return
	current = maxf(current - amount, 0.0)
	_invulnerable_timer = invulnerability_time
	damaged.emit(amount)
	_emit_changed()
	if current <= 0.0:
		is_dead = true
		died.emit()


## Лечит. Возвращает false, если лечить нечего.
func heal(amount: float) -> bool:
	if is_dead or is_full():
		return false
	var old := current
	current = minf(current + amount, max_health)
	healed.emit(current - old)
	_emit_changed()
	return true


func kill() -> void:
	_invulnerable_timer = 0.0
	take_damage(current)


func is_full() -> bool:
	return current >= max_health


func get_ratio() -> float:
	return current / max_health


func _emit_changed() -> void:
	health_changed.emit(current, max_health)


## Ищет компонент Health в узле или среди его детей
static func find_in(node: Node) -> Health:
	if node == null:
		return null
	if node is Health:
		return node
	for child in node.get_children():
		if child is Health:
			return child
	return null
