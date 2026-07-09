extends CanvasLayer
class_name DialogueSystem
## Kotak dialog dengan efek mengetik (typewriter), seperti diminta di desain.
## Pasang node ini sebagai child dari scene Story, lalu panggil show_line().

signal line_finished
signal advanced # dipanggil tiap kali player tap/klik untuk lanjut

@export var chars_per_second := 32.0

var _box: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _full_text := ""
var _typing := false

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	_box = PanelContainer.new()
	_box.anchor_left = 0.05
	_box.anchor_right = 0.95
	_box.anchor_top = 0.72
	_box.anchor_bottom = 0.96
	add_child(_box)

	var vb := VBoxContainer.new()
	_box.add_child(vb)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 14)
	_speaker_label.modulate = Color(0.55, 0.85, 1.0)
	vb.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.fit_content = true
	_text_label.bbcode_enabled = false
	_text_label.custom_minimum_size = Vector2(0, 60)
	vb.add_child(_text_label)

func show_line(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_full_text = text
	_text_label.text = ""
	_typing = true
	_type_text()

func _type_text() -> void:
	var i := 0
	while i <= _full_text.length():
		if not _typing:
			_text_label.text = _full_text
			break
		_text_label.text = _full_text.substr(0, i)
		i += 1
		await get_tree().create_timer(1.0 / chars_per_second).timeout
	_typing = false
	emit_signal("line_finished")

func skip_typing() -> void:
	# tap sekali saat sedang mengetik = langsung tampilkan full text
	if _typing:
		_typing = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		if _typing:
			skip_typing()
		else:
			emit_signal("advanced")
