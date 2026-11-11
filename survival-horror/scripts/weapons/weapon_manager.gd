# res://scripts/weapons/weapon_manager.gd
extends Node3D
class_name WeaponManager
## Оружие игрока. Должен быть дочерним узлом Camera3D в сцене игрока.

signal weapon_equipped(weapon: WeaponData)
signal fired(weapon: WeaponData)

@export var require_aim_to_fire: bool = false  ## true = стрелять можно только прицелившись
@export var aim_speed: float = 10.0
@export var no_ammo_message: String = "Нет патронов"
@export var bullet_hole_lifetime: float = 10.0

var current: WeaponData = null
var is_aiming: bool = false
var is_reloading: bool = false

var _loaded: Dictionary = {}       # id оружия -> патронов в магазине
var _cooldown: float = 0.0
var _reload_token: int = 0
var _view_model: Node3D
var _muzzle_light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _default_fov: float
var _hole_mesh: SphereMesh

@onready var camera: Camera3D = get_parent() as Camera3D
@onready var player: Player = owner as Player


func _ready() -> void:
	add_to_group("weapon_manager")
	_default_fov = camera.fov

	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	_muzzle_light.omni_range = 6.0
	_muzzle_light.light_energy = 0.0
	add_child(_muzzle_light)

	# Простая «дырка от пули» на случай, если у оружия нет своего эффекта
	_hole_mesh = SphereMesh.new()
	_hole_mesh.radius = 0.012
	_hole_mesh.height = 0.024
	var hole_material := StandardMaterial3D.new()
	hole_material.albedo_color = Color.BLACK
	_hole_mesh.material = hole_material

	Inventory.changed.connect(_on_inventory_changed)
	call_deferred("_emit_state")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var can_act := current != null and player.can_move and not player.is_dead

	# Прицеливание: приближение камеры и оружие к центру экрана
	is_aiming = can_act and Input.is_action_pressed("aim")
	var target_fov := current.aim_fov if (is_aiming and current) else _default_fov
	camera.fov = lerpf(camera.fov, target_fov, aim_speed * delta)
	if current:
		var target_pos := current.aim_position if is_aiming else current.view_position
		position = position.lerp(target_pos, aim_speed * delta)

	if not can_act:
		return

	var wants_fire := Input.is_action_pressed("fire") if current.automatic \
		else Input.is_action_just_pressed("fire")
	if wants_fire and _cooldown <= 0.0 and (is_aiming or not require_aim_to_fire):
		_try_fire()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload") and current and player.can_move:
		reload()


# ---------- ЭКИПИРОВКА ----------
func equip(weapon: WeaponData) -> void:
	_cancel_reload()
	current = weapon
	if not _loaded.has(weapon.id):
		_loaded[weapon.id] = clampi(weapon.starting_loaded, 0, weapon.magazine_size)
	_build_view_model()
	weapon_equipped.emit(weapon)
	_emit_state()


func unequip() -> void:
	_cancel_reload()
	current = null
	_build_view_model()
	weapon_equipped.emit(null)
	_emit_state()


func get_loaded() -> int:
	if current == null:
		return 0
	return int(_loaded.get(current.id, 0))


## Патроны в запасе (в инвентаре). -1 = бесконечно.
func get_reserve() -> int:
	if current == null:
		return 0
	if current.ammo_item == null:
		return -1
	return Inventory.count(current.ammo_item.id)


# ---------- СТРЕЛЬБА ----------
func _try_fire() -> void:
	if is_reloading:
		return
	var loaded := get_loaded()
	if loaded <= 0:
		_play(current.empty_sound)
		_cooldown = 0.3
		if current.auto_reload:
			reload()
		return

	_loaded[current.id] = loaded - 1
	_cooldown = 1.0 / current.fire_rate

	# Урон собираем по целям, чтобы дробь дробовика складывалась в один удар
	var spread := current.aim_spread if is_aiming else current.hip_spread
	var hits := {}
	for i in current.pellets:
		_fire_ray(spread, hits)
	for health in hits:
		health.take_damage(hits[health])

	_muzzle_flash()
	_apply_recoil()
	_play(current.fire_sound)
	fired.emit(current)
	GameEvents.make_noise(global_position, current.noise_radius)
	_emit_ammo()


func _fire_ray(spread: float, hits: Dictionary) -> void:
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var direction := _apply_spread(-camera.global_basis.z, spread)
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * current.max_range)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	var collider := hit.collider as Node
	var health := Health.find_in(collider)
	if health:
		hits[health] = hits.get(health, 0.0) + current.damage
	if collider is RigidBody3D:
		var body := collider as RigidBody3D
		body.apply_impulse(direction * current.impact_force, hit.position - body.global_position)
	_spawn_impact(hit.position, hit.normal, collider)


func _apply_spread(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var cam_basis := camera.global_basis
	var yaw := deg_to_rad(randf_range(-degrees, degrees))
	var pitch := deg_to_rad(randf_range(-degrees, degrees))
	return direction.rotated(cam_basis.y, yaw).rotated(cam_basis.x, pitch).normalized()


func _spawn_impact(point: Vector3, normal: Vector3, collider: Node) -> void:
	var impact: Node3D
	if current.impact_scene:
		impact = current.impact_scene.instantiate() as Node3D
	else:
		var hole := MeshInstance3D.new()
		hole.mesh = _hole_mesh
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact = hole

	# Цепляем к объекту, в который попали, чтобы дырка двигалась вместе с дверью
	var parent: Node = collider if collider is Node3D else get_tree().current_scene
	parent.add_child(impact)
	impact.global_position = point + normal * 0.005
	if not normal.is_equal_approx(Vector3.UP) and not normal.is_equal_approx(Vector3.DOWN):
		impact.look_at(point + normal, Vector3.UP)
	get_tree().create_timer(bullet_hole_lifetime, false).timeout.connect(impact.queue_free)


func _muzzle_flash() -> void:
	_muzzle_light.light_energy = 4.0
	var tween := create_tween()
	tween.tween_property(_muzzle_light, "light_energy", 0.0, 0.08)


func _apply_recoil() -> void:
	var limit := deg_to_rad(player.max_look_angle)
	player.head.rotation.x = clampf(player.head.rotation.x + deg_to_rad(current.recoil), -limit, limit)
	position.z += 0.06  # оружие дёргается назад и плавно возвращается


# ---------- ПЕРЕЗАРЯДКА ----------
func reload() -> void:
	if current == null or is_reloading:
		return
	var need := current.magazine_size - get_loaded()
	if need <= 0:
		return
	var reserve := get_reserve()
	if reserve == 0:
		GameEvents.show_message(no_ammo_message)
		return

	is_reloading = true
	_reload_token += 1
	var token := _reload_token
	var weapon := current
	_play(weapon.reload_sound)

	# Оружие уходит вниз на время перезарядки
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:x", -35.0, 0.2)

	await get_tree().create_timer(weapon.reload_time, false).timeout

	# Перезарядку могли прервать (сменили оружие)
	if token != _reload_token:
		return

	var take := need
	if weapon.ammo_item:
		take = mini(need, Inventory.count(weapon.ammo_item.id))
		Inventory.remove_item(weapon.ammo_item.id, take)
	_loaded[weapon.id] = get_loaded() + take

	is_reloading = false
	create_tween().tween_property(self, "rotation_degrees:x", 0.0, 0.2)
	_emit_ammo()


func _cancel_reload() -> void:
	_reload_token += 1
	is_reloading = false
	rotation_degrees = Vector3.ZERO


# ---------- ВИД И ЗВУК ----------
func _build_view_model() -> void:
	if _view_model:
		_view_model.queue_free()
		_view_model = null
	if current == null:
		return

	if current.view_model:
		_view_model = current.view_model.instantiate() as Node3D
	else:
		# Заглушка: серый брусок, пока нет модели
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.08, 0.3)
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position.z = -0.1
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_view_model = mesh
	add_child(_view_model)
	position = current.view_position
	_muzzle_light.position = current.muzzle_offset


func _play(stream: AudioStream) -> void:
	if stream:
		_audio.stream = stream
		_audio.play()


func _emit_state() -> void:
	GameEvents.weapon_changed.emit(current)
	_emit_ammo()


func _emit_ammo() -> void:
	if current:
		GameEvents.ammo_changed.emit(get_loaded(), get_reserve())
		



func _on_inventory_changed() -> void:
	if current and not _has_weapon_item(current):
		unequip()
	_emit_ammo()


func _has_weapon_item(weapon: WeaponData) -> bool:
	for stack in Inventory.slots:
		if stack and stack.item.use_effect is EquipWeaponEffect \
				and (stack.item.use_effect as EquipWeaponEffect).weapon == weapon:
			return true
	return false
