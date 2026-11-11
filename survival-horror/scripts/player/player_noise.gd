# res://scripts/player/player_noise.gd
extends Node
class_name PlayerNoise
## Шум шагов игрока. Бег слышно далеко, на корточках — тишина.
## Дочерний узел Player.

@export var walk_radius: float = 3.0
@export var sprint_radius: float = 10.0
@export var crouch_radius: float = 0.0   ## 0 = полностью бесшумно
@export var interval: float = 0.5        ## как часто «звучит» шаг

@onready var player: Player = get_parent() as Player

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead or not player.is_on_floor():
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.5:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval

	var radius := walk_radius
	if player.is_sprinting:
		radius = sprint_radius
	elif player.is_crouching:
		radius = crouch_radius
	if radius > 0.0:
		GameEvents.make_noise(player.global_position, radius)
