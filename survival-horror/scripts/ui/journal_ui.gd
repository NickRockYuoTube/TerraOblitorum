extends Control
class_name JournalUI
## Окно блокнота. Открывается по действию "journal" или при чтении записки.

@export var note_list: ItemList
@export var title_label: Label
@export var note_text: RichTextLabel
@export var note_image: TextureRect       ## необязательно
@export var hint_prefix: String = "Подсказка: "
@export var empty_text: String = "Блокнот пуст."

var is_open: bool = false


func _ready() -> void:
	# Если поля не назначены, ищем узлы по имени
	if note_list == null:
		note_list = find_child("NoteList", true, false) as ItemList
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if note_text == null:
		note_text = find_child("NoteText", true, false) as RichTextLabel
	if note_image == null:
		note_image = find_child("NoteImage", true, false) as TextureRect
	if note_list == null or title_label == null or note_text == null:
		push_error("JournalUI: не найдены узлы NoteList / TitleLabel / NoteText")
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	note_text.bbcode_enabled = true
	note_list.item_selected.connect(_on_item_selected)
	Journal.changed.connect(_refresh_list)
	GameEvents.note_open_requested.connect(open)
	_refresh_list()


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") \
				or event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


## Открыть блокнот. Если передана записка, сразу показать её.
func open(note: NoteData = null) -> void:
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_list()

	if note:
		var index := Journal.notes.find(note)
		if index >= 0:
			note_list.select(index)
		_display(note)
	elif not Journal.notes.is_empty():
		var last := Journal.notes.size() - 1  # по умолчанию — самая свежая запись
		note_list.select(last)
		_display(Journal.notes[last])
	else:
		_display_empty()
	note_list.grab_focus()


func close() -> void:
	is_open = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_list() -> void:
	note_list.clear()
	for note in Journal.notes:
		var label := note.title
		if note.type == NoteData.NoteType.HINT:
			label = hint_prefix + label
		note_list.add_item(label)


func _on_item_selected(index: int) -> void:
	_display(Journal.notes[index])


func _display(note: NoteData) -> void:
	title_label.text = note.title
	note_text.text = note.text
	note_text.scroll_to_line(0)
	if note_image:
		note_image.texture = note.image
		note_image.visible = note.image != null


func _display_empty() -> void:
	title_label.text = ""
	note_text.text = empty_text
	if note_image:
		note_image.visible = false
