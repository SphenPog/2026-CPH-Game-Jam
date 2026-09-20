extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var indicator: Label = %Indicator
@onready var portrait_texture: TextureRect = %PortraitTexture

@export var seconds_per_character: float = 0.03

var current_lines: Array[String] = []
var current_line_index: int = 0
var is_typing: bool = false
var is_active: bool = false
var _tween: Tween

func _ready() -> void:
	panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if is_typing:
			_skip_typing()
		else:
			_advance_line()

func show_dialogue(speaker_name: String, lines: Array[String], portrait: Texture2D = null) -> void:
	if lines.is_empty():
		return

	current_lines = lines
	current_line_index = 0
	is_active = true
	dialogue_started.emit()

	if speaker_name.strip_edges().is_empty():
		speaker_label.hide()
	else:
		speaker_label.text = speaker_name
		speaker_label.show()
	
	if portrait:
		portrait_texture.texture = portrait
		portrait_texture.show()
	else:
		portrait_texture.texture = null
		portrait_texture.hide()
		
	panel.show()
	_display_current_line()

func _display_current_line() -> void:
	var line_text = current_lines[current_line_index]
	text_label.text = line_text
	text_label.visible_ratio = 0.0
	indicator.hide()
	is_typing = true

	var duration = line_text.length() * seconds_per_character

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_typing_finished)

func _skip_typing() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	text_label.visible_ratio = 1.0
	_on_typing_finished()

func _on_typing_finished() -> void:
	is_typing = false
	indicator.show()

func _advance_line() -> void:
	current_line_index += 1
	if current_line_index < current_lines.size():
		_display_current_line()
	else:
		_close_dialogue()

func _close_dialogue() -> void:
	is_active = false
	panel.hide()
	dialogue_finished.emit()
