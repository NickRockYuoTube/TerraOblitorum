extends Resource
class_name NoteData
## Записка или подсказка. Создаётся как ресурс .tres.

enum NoteType { DOCUMENT, HINT }

@export var id: String = ""               ## уникальный ID, например "note_basement"
@export var title: String = "Записка"
@export_multiline var text: String = ""   ## поддерживает BBCode: [b]жирный[/b], [i]курсив[/i], [color=red]...[/color]
@export var type: NoteType = NoteType.DOCUMENT
@export var image: Texture2D              ## необязательная картинка (фото, схема, рисунок)
