extends CharacterBody3D
class_name Player
## Контроллер игрока от первого лица для survival horror.
## Все параметры настраиваются в инспекторе.

signal stamina_changed(current: float, max_value: float)
signal crouch_changed(is_crouching: bool)

# ---------- НАСТРОЙКИ ----------
@export var health: Health                 ## компонент здоровья (дочерний узел)

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 4.5
@export var crouch_speed: float = 1.3
@export var acceleration: float = 10.0     ## насколько быстро разгоняемся (м/с²)
@export var deceleration: float = 12.0     ## насколько быстро тормозим
@export var gravity_multiplier: float = 1.0

@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export_range(30.0, 89.0) var max_look_angle: float = 85.0

@export_group("Crouch")
@export var crouch_toggle: bool = false    ## true = нажал/отпустил, false = удерживать
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var crouch_transition_speed: float = 8.0
@export var eye_offset: float = 0.15       ## насколько глаза ниже макушки

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 20.0    ## расход в секунду при беге
@export var stamina_regen: float = 12.0    ## восстановление в секунду
@export var stamina_regen_delay: float = 1.0
@export_range(0.0, 1.0) var exhausted_recover_ratio: float = 0.3 ## после полного истощения бег вернётся при 30%

@export_group("Head Bob")
@export var bob_enabled: bool = true
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.04

@export_group("Death")
@export var death_fall_time: float = 1.0
@export var death_camera_height: float = 0.3

# ---------- ССЫЛКИ НА УЗЛЫ ----------
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

# ---------- СОСТОЯНИЕ ----------
var can_move: bool = true    ## выключаем во время инвентаря, катсцен, головоломок
var can_look: bool = true
var is_crouching: bool = false
var is_sprinting: bool = false
var is_dead: bool = false
var stamina: float

var _exhausted: bool = false
var _regen_timer: float = 0.0
var _bob_time: float = 0.0
var _current_height: float
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stamina = max_stamina
	# Делаем форму уникальной, чтобы менять её высоту без влияния на другие копии
	collision.shape = collision.shape.duplicate()
	_current_height = stand_height
	_apply_height(_current_height)

	if health == null:
		health = Health.find_in(self)
	if health:
		health.health_changed.connect(_on_health_changed)
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	else:
		push_warning("Player: нет компонента Health")


func _unhandled_input(event: InputEvent) -> void:
	# Обзор мышью: тело крутится по горизонтали, голова по вертикали
	if event is InputEventMouseMotion and can_look \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		var limit := deg_to_rad(max_look_angle)
		head.rotation.x = clamp(head.rotation.x, -limit, limit)

	if crouch_toggle and can_move and event.is_action_pressed("crouch"):
		if is_crouching:
			_try_stand_up()
		else:
			_set_crouching(true)


func _physics_process(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta

	# Мёртвый игрок только плавно останавливается
	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		move_and_slide()
		return

	_handle_crouch(delta)

	# Направление движения относительно того, куда смотрит игрок
	var input_dir := Vector2.ZERO
	if can_move:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var is_moving := direction != Vector3.ZERO

	# Бег возможен только вперёд, стоя и при наличии выносливости
	is_sprinting = can_move and is_moving and input_dir.y < 0.0 \
		and Input.is_action_pressed("sprint") \
		and not is_crouching and not _exhausted

	_handle_stamina(delta)

	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed

	# Плавный разгон и торможение, чтобы движение ощущалось «весомым»
	var target_velocity := direction * target_speed
	var accel := acceleration if is_moving else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	move_and_slide()
	_handle_head_bob(delta)


# ---------- ПРИСЕДАНИЕ ----------
func _handle_crouch(delta: float) -> void:
	if not crouch_toggle:
		if can_move and Input.is_action_pressed("crouch"):
			_set_crouching(true)
		elif is_crouching:
			_try_stand_up()

	var target := crouch_height if is_crouching else stand_height
	if not is_equal_approx(_current_height, target):
		_current_height = lerp(_current_height, target, crouch_transition_speed * delta)
		if abs(_current_height - target) < 0.005:
			_current_height = target
		_apply_height(_current_height)


func _try_stand_up() -> void:
	# Проверяем, не упрёмся ли головой в потолок, если встанем
	var rise := stand_height - _current_height
	if not test_move(global_transform, Vector3.UP * rise):
		_set_crouching(false)


func _set_crouching(value: bool) -> void:
	if is_crouching == value:
		return
	is_crouching = value
	crouch_changed.emit(is_crouching)


func _apply_height(h: float) -> void:
	var capsule := collision.shape as CapsuleShape3D
	capsule.height = h
	collision.position.y = h * 0.5   # низ капсулы всегда на уровне ног
	head.position.y = h - eye_offset


# ---------- ВЫНОСЛИВОСТЬ ----------
func _handle_stamina(delta: float) -> void:
	var old := stamina
	if is_sprinting:
		stamina = max(stamina - stamina_drain * delta, 0.0)
		_regen_timer = stamina_regen_delay
		if stamina <= 0.0:
			_exhausted = true
	else:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			stamina = min(stamina + stamina_regen * delta, max_stamina)
		if _exhausted and stamina >= max_stamina * exhausted_recover_ratio:
			_exhausted = false

	if not is_equal_approx(old, stamina):
		stamina_changed.emit(stamina, max_stamina)


# ---------- ПОКАЧИВАНИЕ КАМЕРЫ ----------
func _handle_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_offset := Vector3.ZERO

	if bob_enabled and is_on_floor() and horizontal_speed > 0.1:
		_bob_time += delta * horizontal_speed * bob_frequency
		target_offset.y = sin(_bob_time * 2.0) * bob_amplitude   # вверх-вниз на каждый шаг
		target_offset.x = cos(_bob_time) * bob_amplitude * 0.5   # лёгкое покачивание в стороны

	camera.position = camera.position.lerp(target_offset, 10.0 * delta)


# ---------- ЗДОРОВЬЕ ----------
func _on_health_changed(current: float, max_value: float) -> void:
	GameEvents.player_health_changed.emit(current, max_value)


func _on_damaged(amount: float) -> void:
	GameEvents.player_damaged.emit(amount)


func _on_died() -> void:
	is_dead = true
	set_controls_enabled(false)
	# Камера «падает» на пол и заваливается набок
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(head, "position:y", death_camera_height, death_fall_time)
	tween.parallel().tween_property(head, "rotation:z", deg_to_rad(70.0), death_fall_time)
	GameEvents.player_died.emit()


# ---------- ПУБЛИЧНЫЕ МЕТОДЫ (для других систем) ----------
## Заблокировать/разблокировать управление (инвентарь, записки, катсцены)
func set_controls_enabled(enabled: bool) -> void:
	can_move = enabled
	can_look = enabled
	if not enabled:
		is_sprinting = false
