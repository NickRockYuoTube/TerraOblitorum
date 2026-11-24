extends CharacterBody3D
class_name Player
## Контроллер игрока от первого лица — Terra Oblitorum.
## Шаг 1: ходьба, бег (с выносливостью или без), прыжок, присед,
## обзор мышью, покачивание камеры, взаимодействие на E.
##
## Ожидаемое дерево сцены:
##   Player (CharacterBody3D)        <- этот скрипт
##   ├─ CollisionShape3D             (CapsuleShape3D, radius 0.35)
##   ├─ Head (Node3D)
##   │  └─ Camera3D
##   │     └─ InteractRay (RayCast3D)
##   ├─ Health (Node)                 <- health.gd
##   └─ DamageOverlay (CanvasLayer)   <- damage_overlay.gd

## Сигналы — для будущего HUD, звуков и врагов.
signal interact_target_changed(target: Node, text: String)  ## навели/убрали прицел с объекта
signal footstep                                              ## каждый шаг (для звука шагов)
signal stamina_changed(value: float, max_value: float)

# ---------------------------------------------------------------- Параметры
@export_group("Движение")
@export var walk_speed := 3.0
@export var sprint_speed := 5.5
@export var crouch_speed := 1.6
@export var acceleration := 12.0      ## насколько быстро набирается/сбрасывается скорость на земле
@export var air_control := 2.0        ## управление в воздухе (меньше = «тяжелее» прыжок)

@export_group("Прыжок")
@export var jump_enabled := true      ## в GDD пока «уточнить» — можно выключить галочкой
@export var jump_velocity := 4.2

@export_group("Выносливость")
@export var use_stamina := true       ## выключи — и Shift станет бегом без ограничений
@export var stamina_max := 5.0        ## секунд непрерывного бега
@export var stamina_regen := 1.0      ## восстановление в секунду
@export var stamina_regen_delay := 1.0  ## пауза перед восстановлением
@export var stamina_min_to_sprint := 1.5  ## после полного истощения бег снова доступен с этого уровня

@export_group("Приседание")
@export var stand_height := 1.8
@export var crouch_height := 1.1
@export var crouch_transition := 10.0  ## скорость перехода стоя <-> сидя
@export var eye_offset := 0.15         ## глаза ниже макушки на столько

@export_group("Камера")
@export var mouse_sensitivity := 0.12  ## градусов на пиксель движения мыши
@export var pitch_limit := 85.0
@export var head_bob := true
@export var bob_amplitude := 0.035
@export var step_length := 0.75        ## метров на шаг (покачивание и сигнал footstep)

@export_group("Взаимодействие")
@export var interact_distance := 2.0

@export_group("Здоровье")
@export var danger_speed_multiplier := 1.0  ## скорость в «Опасности» (0.7 = хромает, как в RE; 1.0 = выкл)
@export var hit_kick_degrees := 4.0         ## толчок камеры при ударе
@export var death_restart_delay := 3.0      ## через сколько секунд после смерти перезапуск

# ---------------------------------------------------------------- Узлы
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health: Health = get_node_or_null("Health")

# ---------------------------------------------------------------- Состояние
## Блокирует управление (инвентарь, журнал, начертание Трикветры, катсцены).
var input_locked := false

var is_crouching := false
var is_sprinting := false
var is_dead := false
var stamina := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _capsule: CapsuleShape3D
var _current_height := 0.0
var _exhausted := false
var _stamina_delay := 0.0
var _step_distance := 0.0
var _interact_target: Node = null


func _ready() -> void:
	add_to_group("player")  # враги будут искать игрока по группе
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Делаем форму уникальной, иначе присед менял бы общий ресурс капсулы
	_capsule = (collision.shape as CapsuleShape3D).duplicate()
	collision.shape = _capsule
	_current_height = stand_height
	_apply_height(stand_height)

	stamina = stamina_max
	interact_ray.target_position = Vector3(0, 0, -interact_distance)
	interact_ray.add_exception(self)

	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	else:
		push_warning("Player: нет дочернего узла Health — здоровье не работает")


func _unhandled_input(event: InputEvent) -> void:
	# ВРЕМЕННО: Esc отпускает мышь, клик возвращает. Потом заменит меню паузы.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if input_locked:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(deg_to_rad(-motion.relative.x * mouse_sensitivity))
		head.rotation.x = clampf(
			head.rotation.x - deg_to_rad(motion.relative.y * mouse_sensitivity),
			deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))

	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_dead:
		# Мёртвый игрок только падает и тормозит, камерой управляет анимация смерти
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-8.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-8.0 * delta))
		move_and_slide()
		return

	var input_dir := Vector2.ZERO
	if not input_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	_update_crouch(delta)
	_update_sprint(delta, input_dir)

	if (jump_enabled and not input_locked and not is_crouching
			and is_on_floor() and Input.is_action_just_pressed("jump")):
		velocity.y = jump_velocity

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed
	if health and health.state == Health.State.DANGER:
		speed *= danger_speed_multiplier

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target := direction * speed
	var accel := acceleration if is_on_floor() else air_control
	var weight := 1.0 - exp(-accel * delta)  # плавно и не зависит от FPS
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	move_and_slide()

	_update_head_bob(delta)
	_update_interact_target()


# ---------------------------------------------------------------- Присед
func _update_crouch(delta: float) -> void:
	var wants_crouch := not input_locked and Input.is_action_pressed("crouch")
	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false  # встаём, только если над головой свободно

	var target_height := crouch_height if is_crouching else stand_height
	_current_height = lerpf(_current_height, target_height, 1.0 - exp(-crouch_transition * delta))
	_apply_height(_current_height)


func _apply_height(height: float) -> void:
	# Начало координат игрока — у ног, поэтому капсула растёт вверх от пола
	_capsule.height = height
	collision.position.y = height * 0.5
	head.position.y = height - eye_offset


func _can_stand_up() -> bool:
	var rise := stand_height - _current_height
	if rise <= 0.01:
		return true
	# Пробуем «приподнять» капсулу: если упрёмся — над нами потолок
	return not test_move(global_transform, Vector3.UP * rise)


# ---------------------------------------------------------------- Бег
func _update_sprint(delta: float, input_dir: Vector2) -> void:
	# Бежать можно только вперёд (или вперёд-вбок), стоя и на земле
	var wants_sprint := (not input_locked and Input.is_action_pressed("sprint")
			and input_dir.y < -0.1 and not is_crouching and is_on_floor())

	if not use_stamina:
		is_sprinting = wants_sprint
		return

	if _exhausted and stamina >= stamina_min_to_sprint:
		_exhausted = false
	is_sprinting = wants_sprint and not _exhausted

	var old_stamina := stamina
	if is_sprinting:
		stamina = maxf(stamina - delta, 0.0)
		_stamina_delay = stamina_regen_delay
		if stamina <= 0.0:
			_exhausted = true
	elif _stamina_delay > 0.0:
		_stamina_delay -= delta
	else:
		stamina = minf(stamina + stamina_regen * delta, stamina_max)

	if stamina != old_stamina:
		stamina_changed.emit(stamina, stamina_max)


# ---------------------------------------------------------------- Камера
func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		var prev_steps := floorf(_step_distance / step_length)
		_step_distance += horizontal_speed * delta
		if floorf(_step_distance / step_length) > prev_steps:
			footstep.emit()
		if head_bob:
			var phase := _step_distance / step_length * TAU
			camera.position.y = sin(phase) * bob_amplitude            # вверх-вниз на каждый шаг
			camera.position.x = sin(phase * 0.5) * bob_amplitude * 0.5  # влево-вправо на пару шагов
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))


# ---------------------------------------------------------------- Взаимодействие
## Контракт: у объекта (или его родителя) есть метод interact(player).
## Необязательно: get_interact_text() -> String для подсказки в HUD.
func _update_interact_target() -> void:
	var target: Node = null
	if not input_locked and interact_ray.is_colliding():
		target = _find_interactable(interact_ray.get_collider() as Node)

	if target != _interact_target:
		_interact_target = target
		var text := ""
		if target and target.has_method("get_interact_text"):
			text = target.get_interact_text()
		interact_target_changed.emit(target, text)


func _find_interactable(node: Node) -> Node:
	# Луч попадает в коллайдер, а скрипт часто висит на родителе — поднимаемся на пару уровней
	var depth := 0
	while node and depth < 3:
		if node.has_method("interact"):
			return node
		node = node.get_parent()
		depth += 1
	return null


func _try_interact() -> void:
	if _interact_target and is_instance_valid(_interact_target):
		_interact_target.interact(self)


# ---------------------------------------------------------------- Урон и смерть
func _on_damaged(_amount: int, _source: Node) -> void:
	# Камеру резко «подбрасывает» вверх и плавно возвращает
	var kick := deg_to_rad(hit_kick_degrees)
	var tween := create_tween()
	tween.tween_property(camera, "rotation:x", kick, 0.05)
	tween.tween_property(camera, "rotation:x", 0.0, 0.25)


func _on_died() -> void:
	is_dead = true
	input_locked = true
	is_sprinting = false
	if _interact_target:
		_interact_target = null
		interact_target_changed.emit(null, "")

	# Камера падает на пол и заваливается набок
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(head, "position:y", 0.3, 0.9)
	tween.tween_property(head, "rotation:z", deg_to_rad(75.0), 0.9)
	tween.tween_property(camera, "position", Vector3.ZERO, 0.3)

	# Пока нет сохранений — просто перезапускаем уровень.
	# Потом здесь будет «загрузить последнее сохранение».
	await get_tree().create_timer(death_restart_delay).timeout
	get_tree().reload_current_scene()
