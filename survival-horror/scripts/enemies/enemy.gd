# res://scripts/enemies/enemy.gd
extends CharacterBody3D
class_name Enemy
## Враг ближнего боя: патруль, зрение, слух, преследование, поиск, атака.
## Нужны дочерние узлы: NavigationAgent3D, CollisionShape3D, Health.

signal state_changed(new_state: State)

enum State { IDLE, PATROL, CHASE, SEARCH, ATTACK, STAGGER, DEAD }

@export var health: Health

@export_group("Movement")
@export var walk_speed: float = 1.4
@export var chase_speed: float = 3.0
@export var acceleration: float = 8.0
@export var turn_speed: float = 6.0
@export var arrive_distance: float = 0.6

@export_group("Patrol")
@export var patrol_points: Array[Node3D] = []   ## Marker3D на уровне; пусто = стоит на месте
@export var patrol_wait: float = 2.0

@export_group("Senses")
@export var sight_range: float = 15.0
@export_range(10.0, 360.0) var sight_angle: float = 110.0
@export var close_awareness: float = 2.0   ## на таком расстоянии замечает даже спиной
@export var eye_height: float = 1.6
@export var hearing_multiplier: float = 1.0  ## 2 = слышит вдвое дальше, 0 = глухой
@export var lose_sight_time: float = 4.0     ## сколько гонится вслепую, потеряв из виду
@export var search_time: float = 5.0         ## сколько осматривается на месте

@export_group("Attack")
@export var attack_damage: float = 20.0
@export var attack_range: float = 1.6
@export var attack_windup: float = 0.5     ## замах: время, чтобы увернуться
@export var attack_recovery: float = 0.8

@export_group("Reaction")
@export var stagger_time: float = 0.35     ## оглушение от попадания (0 = не реагирует)
@export var corpse_lifetime: float = 0.0   ## 0 = тело остаётся навсегда
@export var drop_scene: PackedScene        ## что выпадает после смерти

@export_group("Animation")
@export var animation_player: AnimationPlayer  ## необязательно
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_run: String = "run"
@export var anim_attack: String = "attack"
@export var anim_hit: String = "hit"
@export var anim_death: String = "death"

@export_group("Debug")
@export var debug_label: Label3D           ## показывает состояние над головой

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var state: State = State.IDLE
var _state_time: float = 0.0
var _wait_timer: float = 0.0
var _patrol_index: int = 0
var _last_known: Vector3
var _search_pos: Vector3
var _search_timer: float = 0.0
var _lost_timer: float = 0.0
var _sense_timer: float = 0.0
var _sees_player: bool = false
var _attack_done: bool = false
var _player: Player
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	if health == null:
		health = Health.find_in(self)
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	else:
		push_warning("Enemy '%s': нет компонента Health" % name)
	if debug_label == null:
		debug_label = find_child("DebugLabel", true, false) as Label3D
	GameEvents.noise_emitted.connect(_on_noise)

	# Ждём один физический кадр, пока навигация загрузится
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player") as Player
	_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_state_time += delta
	_update_senses(delta)

	match state:
		State.IDLE:
			_stop(delta)
			_play(anim_idle)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
		State.ATTACK:
			_process_attack(delta)
		State.STAGGER:
			_stop(delta)
			if _state_time >= stagger_time:
				_set_state(State.CHASE)

	move_and_slide()


# ---------- СОСТОЯНИЯ ----------
func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		_set_state(State.IDLE)
		return
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_stop(delta)
		_play(anim_idle)
		return
	var point := patrol_points[_patrol_index]
	if point == null or _move_to(point.global_position, walk_speed, delta):
		_wait_timer = patrol_wait
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
	else:
		_play(anim_walk)


func _process_chase(delta: float) -> void:
	if _player == null or _player.is_dead:
		_go_search(_last_known)
		return
	var distance := global_position.distance_to(_player.global_position)
	if _sees_player and distance <= attack_range:
		_set_state(State.ATTACK)
		return
	if _sees_player:
		_lost_timer = 0.0
		_move_to(_player.global_position, chase_speed, delta)
	else:
		# Потерял из виду: бежит туда, где видел в последний раз
		_lost_timer += delta
		var arrived := _move_to(_last_known, chase_speed, delta)
		if arrived or _lost_timer > lose_sight_time:
			_go_search(_last_known)
			return
	_play(anim_run)


func _process_search(delta: float) -> void:
	if _search_timer <= 0.0 and not _move_to(_search_pos, walk_speed, delta):
		_play(anim_walk)
		return
	# Пришёл на место — осматривается
	_stop(delta)
	_play(anim_idle)
	_search_timer += delta
	rotation.y += delta * 0.8
	if _search_timer >= search_time:
		_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)


func _process_attack(delta: float) -> void:
	_stop(delta)
	if _player:
		_face(_player.global_position - global_position, delta)
	if not _attack_done and _state_time >= attack_windup:
		_attack_done = true
		# Удар засчитывается, только если игрок не успел отойти
		if _player and not _player.is_dead and _player.health \
				and global_position.distance_to(_player.global_position) <= attack_range + 0.4:
			_player.health.take_damage(attack_damage)
	if _state_time >= attack_windup + attack_recovery:
		_set_state(State.CHASE)


func _go_search(position_to_check: Vector3) -> void:
	_search_pos = position_to_check
	_search_timer = 0.0
	_set_state(State.SEARCH)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_attack_done = false
	_lost_timer = 0.0
	match new_state:
		State.ATTACK:
			_play(anim_attack, true)
		State.STAGGER:
			_play(anim_hit, true)
	if debug_label:
		debug_label.text = State.keys()[new_state]
	state_changed.emit(new_state)


# ---------- ОРГАНЫ ЧУВСТВ ----------
func _update_senses(delta: float) -> void:
	# Проверяем зрение 6–7 раз в секунду, а не каждый кадр
	_sense_timer -= delta
	if _sense_timer > 0.0:
		return
	_sense_timer = 0.15
	_sees_player = _can_see_player()
	if _sees_player:
		_last_known = _player.global_position
		if state in [State.IDLE, State.PATROL, State.SEARCH]:
			_set_state(State.CHASE)


func _can_see_player() -> bool:
	if _player == null or _player.is_dead:
		return false
	var eye := global_position + Vector3.UP * eye_height
	var target := _player.head.global_position
	var to_target := target - eye
	var distance := to_target.length()
	if distance > sight_range:
		return false
	# Угол обзора (кроме случая, когда игрок совсем рядом)
	if distance > close_awareness:
		var forward := -global_basis.z
		var flat := Vector3(to_target.x, 0.0, to_target.z).normalized()
		if rad_to_deg(forward.angle_to(flat)) > sight_angle * 0.5:
			return false
	# Не загораживает ли стена
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _on_noise(noise_position: Vector3, radius: float) -> void:
	if state in [State.CHASE, State.ATTACK, State.STAGGER, State.DEAD]:
		return
	if global_position.distance_to(noise_position) <= radius * hearing_multiplier:
		_go_search(noise_position)


# ---------- РЕАКЦИИ ----------
func _on_damaged(_amount: float) -> void:
	if state == State.DEAD:
		return
	# В него стреляли — значит, знает, где игрок
	if _player:
		_last_known = _player.global_position
	if stagger_time > 0.0:
		_set_state(State.STAGGER)
	else:
		_set_state(State.CHASE)


func _on_died() -> void:
	_set_state(State.DEAD)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	if animation_player and animation_player.has_animation(anim_death):
		_play(anim_death, true)
	else:
		# Без анимации просто заваливается назад
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation_degrees:x", 90.0, 0.6)

	if drop_scene:
		var drop := drop_scene.instantiate() as Node3D
		drop.transform = Transform3D(Basis.IDENTITY, position)
		get_parent().add_child.call_deferred(drop)
	if debug_label:
		debug_label.hide()
	if corpse_lifetime > 0.0:
		get_tree().create_timer(corpse_lifetime, false).timeout.connect(queue_free)


# ---------- ДВИЖЕНИЕ ----------
## Идёт к точке. Возвращает true, когда пришёл (или дойти нельзя).
func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	var flat_distance := Vector2(target.x - global_position.x, target.z - global_position.z).length()
	if flat_distance <= arrive_distance:
		_stop(delta)
		return true
	if agent.target_position.distance_to(target) > 0.3:
		agent.target_position = target
	var next := agent.get_next_path_position()
	if agent.is_navigation_finished():
		_stop(delta)
		return true
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		return false
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	_face(direction, delta)
	return false


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)


func _play(anim: String, restart: bool = false) -> void:
	if animation_player == null or anim == "" or not animation_player.has_animation(anim):
		return
	if restart or animation_player.current_animation != anim:
		animation_player.play(anim)
