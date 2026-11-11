# res://core/save_manager.gd
extends Node
## Сохранение и загрузка игры. Добавлен в Autoload под именем SaveManager.
## Сам находит на уровне двери, предметы, записки, головоломки, врагов
## и разрушаемые объекты и запоминает, что с ними стало.

signal game_saved(slot: int)
signal game_loaded(slot: int)

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1

var slot_count: int = 3
var debug_hotkeys: bool = true   ## F5 — быстрое сохранение в слот 1, F9 — загрузка последнего

var _world: Dictionary = {}           # путь уровня -> состояние мира на этом уровне
var _removed: Dictionary = {}         # объекты текущего уровня, которых больше нет
var _original_keys: Dictionary = {}   # объекты, которые были на уровне изначально
var _pending_player: Dictionary = {}  # данные игрока, ждущие загрузки уровня
var _scene: Node = null
var _unloading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Замечаем, что загрузился новый уровень
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		if scene:
			_on_scene_started(scene)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F5:
		if save_game(0):
			GameEvents.show_message("Быстрое сохранение")
	elif key_event.keycode == KEY_F9:
		var slot := get_latest_slot()
		if slot >= 0:
			load_game(slot)


# =====================================================================
#  ПУБЛИЧНЫЕ МЕТОДЫ
# =====================================================================

func save_game(slot: int) -> bool:
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	if scene == null or player == null or player.is_dead:
		return false

	_snapshot_level(scene)
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": _datetime_text(),
		"level": scene.scene_file_path,
		"level_name": str(scene.name),
		"player": _capture_player(player),
		"inventory": _pack_container(Inventory),
		"storage": _pack_container(Storage),
		"journal": _pack_journal(),
		"world": _world,
	}

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: не удалось записать %s" % _path(slot))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	game_saved.emit(slot)
	return true


func load_game(slot: int) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	_unpack_container(Inventory, data.get("inventory", {}))
	_unpack_container(Storage, data.get("storage", {}))
	_unpack_journal(data.get("journal", []))
	_world = data.get("world", {})
	_pending_player = data.get("player", {})
	_change_scene(str(data.get("level", "")))
	game_loaded.emit(slot)
	return true


## Начать текущий уровень заново, с нуля (без сохранений)
func restart_level() -> void:
	Inventory.clear()
	Storage.clear()
	Journal.clear()
	_world.clear()
	_pending_player = {}
	_unloading = true
	get_tree().paused = false
	get_tree().reload_current_scene()


## Новая игра: всё с нуля и переход на первый уровень
func new_game(level_path: String) -> void:
	Inventory.clear()
	Storage.clear()
	Journal.clear()
	_world.clear()
	_pending_player = {}
	_change_scene(level_path)


## Перейти на другую сцену (например, в главное меню)
func go_to(scene_path: String) -> void:
	_change_scene(scene_path)


func has_any_save() -> bool:
	return get_latest_slot() >= 0


## Номер самого свежего слота или -1, если сохранений нет
func get_latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for i in slot_count:
		var info := get_slot_info(i)
		if not info.is_empty() and float(info.timestamp) > best_time:
			best_time = float(info.timestamp)
			best = i
	return best


## Краткая информация о слоте для меню (пустой словарь, если слот пуст)
func get_slot_info(slot: int) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	return {
		"timestamp": data.get("timestamp", 0.0),
		"datetime": data.get("datetime", ""),
		"level_name": data.get("level_name", ""),
	}


# =====================================================================
#  ЗАГРУЗКА УРОВНЯ
# =====================================================================

func _change_scene(path: String) -> void:
	if path == "":
		push_error("SaveManager: в сохранении нет пути к уровню")
		return
	_unloading = true
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _on_scene_started(scene: Node) -> void:
	_unloading = false
	_removed.clear()
	_original_keys.clear()

	# Запоминаем все сохраняемые объекты уровня и следим, не исчезнут ли они
	for node in _collect_persistent(scene):
		var key := str(scene.get_path_to(node))
		_original_keys[key] = true
		node.tree_exiting.connect(_on_persistent_exiting.bind(key))
		if node is Enemy:
			var enemy_health := Health.find_in(node)
			if enemy_health:
				enemy_health.died.connect(_mark_removed.bind(key))

	var level: Dictionary = _world.get(scene.scene_file_path, {})
	if not level.is_empty():
		_apply_level(scene, level)
	if not _pending_player.is_empty():
		_apply_player(_pending_player)
		_pending_player = {}


func _on_persistent_exiting(key: String) -> void:
	if not _unloading:
		_removed[key] = true


func _mark_removed(key: String) -> void:
	_removed[key] = true


# =====================================================================
#  СОСТОЯНИЕ МИРА
# =====================================================================

func _is_persistent(node: Node) -> bool:
	if node is Door or node is Pickup or node is NotePickup \
			or node is PuzzleElement or node is Enemy:
		return true
	for child in node.get_children():
		if child is Destructible:
			return true
	return false


func _collect_persistent(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	_collect(root, result)
	return result


func _collect(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if _is_persistent(child):
			result.append(child)
		_collect(child, result)


func _snapshot_level(scene: Node) -> void:
	var states := {}
	var dropped := []
	for node in _collect_persistent(scene):
		var key := str(scene.get_path_to(node))
		# Предмет, которого не было на уровне изначально, — выброшенный
		if node is Pickup and not _original_keys.has(key):
			var pickup := node as Pickup
			if pickup.item and pickup.scene_file_path != "":
				dropped.append({
					"scene": pickup.scene_file_path,
					"item": pickup.item.resource_path,
					"amount": pickup.amount,
					"position": _from_vec(pickup.global_position),
				})
			continue
		if _removed.has(key):
			continue
		var state := _capture_state(node)
		if not state.is_empty():
			states[key] = state

	_world[scene.scene_file_path] = {
		"removed": _removed.keys(),
		"states": states,
		"dropped": dropped,
	}


func _apply_level(scene: Node, level: Dictionary) -> void:
	for key in level.get("removed", []):
		_removed[key] = true
		var node := scene.get_node_or_null(NodePath(key))
		if node:
			node.queue_free()

	var states: Dictionary = level.get("states", {})
	for key in states:
		var node := scene.get_node_or_null(NodePath(key))
		if node and not _removed.has(key):
			_apply_state(node, states[key])

	for entry in level.get("dropped", []):
		_spawn_dropped(scene, entry)


func _capture_state(node: Node) -> Dictionary:
	if node is Door:
		var door := node as Door
		return {
			"locked": door.locked,
			"open": door.is_open,
			"angle": door.hinge.rotation_degrees.y if door.hinge else 0.0,
		}
	if node is Pickup:
		return {"amount": (node as Pickup).amount}
	if node is Lever:
		var lever := node as Lever
		return {"solved": lever.is_solved, "on": lever.is_on}
	if node is PuzzleElement:
		return {"solved": (node as PuzzleElement).is_solved}
	return {}


func _apply_state(node: Node, state: Dictionary) -> void:
	if node is Door:
		var door := node as Door
		door.locked = bool(state.get("locked", door.locked))
		door.is_open = bool(state.get("open", false))
		if door.hinge:
			door.hinge.rotation_degrees.y = float(state.get("angle", 0.0))
		door._update_prompt()

	elif node is Pickup:
		var pickup := node as Pickup
		pickup.amount = int(state.get("amount", pickup.amount))
		if pickup.item:
			pickup._update_prompt()

	elif node is Lever:
		var lever := node as Lever
		lever.is_on = bool(state.get("on", lever.is_on))
		if lever.handle:
			lever.handle.rotation_degrees.x = lever.on_angle if lever.is_on else lever.off_angle
		lever.is_solved = bool(state.get("solved", false))
		if lever.one_shot and lever.is_on != lever.start_on and lever.interactable:
			lever.interactable.enabled = false
		if lever.is_solved:
			_restore_targets(lever)

	elif node is PuzzleElement and bool(state.get("solved", false)):
		_restore_solved(node as PuzzleElement)


## Восстановить решённую головоломку без сообщений, звуков и наград
func _restore_solved(element: PuzzleElement) -> void:
	element.is_solved = true
	if element is CodeLock or element is ItemSocket:
		var element_interactable = element.get("interactable")
		if element_interactable is Interactable:
			element_interactable.enabled = false
	if element is ItemSocket:
		var socket := element as ItemSocket
		if socket.placed_visual:
			socket.placed_visual.show()
	if element is PuzzleGroup:
		var group := element as PuzzleGroup
		if group.lock_pieces_when_solved:
			for piece in group.pieces:
				var piece_interactable = piece.get("interactable") if piece else null
				if piece_interactable is Interactable:
					piece_interactable.enabled = false
	_restore_targets(element)


## Повторить действие над целями (убрать преграду, показать объект).
## Двери пропускаем: их состояние сохраняется отдельно.
func _restore_targets(element: PuzzleElement) -> void:
	for target in element.targets:
		if target == null or target is Door:
			continue
		if target.has_method(element.target_method):
			target.call(element.target_method)


func _spawn_dropped(scene: Node, entry: Dictionary) -> void:
	var packed := load(str(entry.get("scene", ""))) as PackedScene
	var item := load(str(entry.get("item", ""))) as ItemData
	if packed == null or item == null:
		return
	var pickup := packed.instantiate() as Node3D
	if pickup is Pickup:
		pickup.item = item
		pickup.amount = int(entry.get("amount", 1))
	scene.add_child(pickup)
	pickup.global_position = _to_vec(entry.get("position", [0, 0, 0]))


# =====================================================================
#  ИГРОК
# =====================================================================

func _capture_player(player: Player) -> Dictionary:
	var data := {
		"position": _from_vec(player.global_position),
		"rot_y": player.rotation.y,
		"pitch": player.head.rotation.x,
	}
	if player.health:
		data["health"] = player.health.current
	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager:
		data["weapon_loaded"] = manager._loaded.duplicate()
		data["weapon"] = manager.current.resource_path if manager.current else ""
	return data


func _apply_player(data: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.global_position = _to_vec(data.get("position", [0, 0, 0]))
	player.rotation.y = float(data.get("rot_y", 0.0))
	player.head.rotation.x = float(data.get("pitch", 0.0))

	if player.health and data.has("health"):
		player.health.current = float(data["health"])
		player.health.health_changed.emit(player.health.current, player.health.max_health)

	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager:
		manager._loaded.clear()
		var loaded: Dictionary = data.get("weapon_loaded", {})
		for weapon_id in loaded:
			manager._loaded[weapon_id] = int(loaded[weapon_id])
		var weapon_path := str(data.get("weapon", ""))
		if weapon_path != "":
			var weapon := load(weapon_path) as WeaponData
			if weapon:
				manager.equip(weapon)


# =====================================================================
#  ИНВЕНТАРЬ, СУНДУК, БЛОКНОТ
# =====================================================================

func _pack_container(container: ItemContainer) -> Dictionary:
	var slots := []
	for stack in container.slots:
		if stack:
			slots.append({"item": stack.item.resource_path, "amount": stack.amount})
		else:
			slots.append(null)
	return {"capacity": container.capacity, "slots": slots}


func _unpack_container(container: ItemContainer, data: Dictionary) -> void:
	if data.is_empty():
		container.clear()
		return
	container.capacity = int(data.get("capacity", container.capacity))
	container.slots.clear()
	container.slots.resize(container.capacity)
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), container.capacity):
		var entry = saved[i]
		if entry is Dictionary:
			var item := load(str(entry.get("item", ""))) as ItemData
			if item:
				container.slots[i] = ItemStack.new(item, int(entry.get("amount", 1)))
	container.changed.emit()


func _pack_journal() -> Array:
	var paths := []
	for note in Journal.notes:
		paths.append(note.resource_path)
	return paths


func _unpack_journal(paths: Array) -> void:
	Journal.notes.clear()
	for path in paths:
		var note := load(str(path)) as NoteData
		if note:
			Journal.notes.append(note)
	Journal.changed.emit()


# =====================================================================
#  ФАЙЛЫ И МЕЛОЧИ
# =====================================================================

func _path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % (slot + 1)


func _read(slot: int) -> Dictionary:
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _datetime_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%02d.%02d.%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _from_vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _to_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
