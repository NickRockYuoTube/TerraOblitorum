# res://scripts/puzzles/puzzle_group.gd
extends PuzzleElement
class_name PuzzleGroup
## Решена, когда решены ВСЕ элементы из списка:
## три предохранителя, комбинация рычагов, несколько замков сразу.

@export var pieces: Array[PuzzleElement] = []
@export var lock_pieces_when_solved: bool = true  ## после решения элементы больше не трогаются


func _ready() -> void:
	super._ready()
	for piece in pieces:
		if piece:
			piece.state_changed.connect(_on_piece_changed.unbind(1))


func _on_piece_changed() -> void:
	if is_solved:
		return
	for piece in pieces:
		if piece and not piece.is_solved:
			return
	if lock_pieces_when_solved:
		for piece in pieces:
			var piece_interactable = piece.get("interactable")
			if piece_interactable is Interactable:
				piece_interactable.enabled = false
	_set_solved(true)
