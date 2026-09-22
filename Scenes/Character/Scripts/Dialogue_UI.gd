extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var indicator: Label = %Indicator
@onready var portrait_texture: TextureRect = %PortraitTexture

@export var seconds_per_character: float = 0.03
@export var next_line_sfx: AudioStream
@export var default_typing_sfx: AudioStream
@export var blip_frequency: int = 2
@export var pitch_variation: float = 0.1

var current_voice_sfx: AudioStream
var current_voice_pitch: float = 1.0

var current_lines: Array[String] = []
var current_line_index: int = 0
var is_typing: bool = false
var is_active: bool = false
var _tween: Tween

var _camera_shots: Dictionary = {}
var _current_npc: Node2D = null
var _last_char_count: int = 0
var _character_counter: int = 0

func _ready() -> void:
	panel.hide()

func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if event.is_echo():
			return
			
		get_viewport().set_input_as_handled()
		
		if is_typing:
			if next_line_sfx:
				AudioManager.play_sfx(next_line_sfx, 1.0, 0.05)
			_skip_typing()
		else:
			if next_line_sfx:
				AudioManager.play_sfx(next_line_sfx, 1.0, 0.05)
			_advance_line()

func show_dialogue(speaker_name: String, lines: Array[String], portrait: Texture2D = null, npc: Node2D = null, camera_shots: Dictionary = {}) -> void:
	if lines.is_empty():
		return
	
	if npc and "voice_sfx" in npc and npc.voice_sfx != null:
		current_voice_sfx = npc.voice_sfx
	else:
		current_voice_sfx = default_typing_sfx
	
	if npc and "voice_pitch" in npc:
		current_voice_pitch = npc.voice_pitch
	else:
		current_voice_pitch = 1.0
	
	current_lines = lines
	current_line_index = 0
	is_active = true
	_current_npc = npc
	_camera_shots = camera_shots
	
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
	_update_camera_focus()
	
	var line_text = current_lines[current_line_index]
	text_label.text = line_text
	text_label.visible_ratio = 0.0
	indicator.hide()
	is_typing = true
	
	_last_char_count = 0
	_character_counter = 0
	
	var total_chars = line_text.length()
	var duration = total_chars * seconds_per_character

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_method(_on_typewriter_step.bind(line_text), 0, total_chars, duration)
	_tween.finished.connect(_on_typing_finished)

func _on_typewriter_step(char_count: int, line_text: String) -> void:
	text_label.visible_characters = char_count
	
	if char_count > _last_char_count:
		for i in range(_last_char_count, char_count):
			if i < line_text.length():
				_play_typewriter_blip(line_text[i])
		_last_char_count = char_count

func _play_typewriter_blip(current_char: String) -> void:
	if current_char == " " or current_char == "\n" or current_char == "\t":
		return

	_character_counter += 1
	if _character_counter % blip_frequency != 0:
		return

	if current_voice_sfx:
		AudioManager.play_sfx(current_voice_sfx, current_voice_pitch, pitch_variation)

func _update_camera_focus() -> void:
	var camera = get_tree().get_first_node_in_group("main_camera")
	if not camera:
		return
	
	var target_node = null
	
	if _camera_shots.has(current_line_index):
		target_node = _resolve_node_target(_camera_shots[current_line_index])
	
	if not is_instance_valid(target_node) and is_instance_valid(_current_npc):
		target_node = _current_npc
	
	if is_instance_valid(target_node):
		camera.set_focus_target(target_node)

func _resolve_node_target(raw_target: Variant) -> Node2D:
	if raw_target is Node2D:
		return raw_target
	
	if raw_target is NodePath or raw_target is String:
		var np = NodePath(raw_target) if raw_target is String else raw_target
		if str(np).is_empty():
			return null
		
		if is_instance_valid(_current_npc):
			var node_from_npc = _current_npc.get_node_or_null(np) as Node2D
			if is_instance_valid(node_from_npc):
				return node_from_npc
		
		if get_tree() and get_tree().current_scene:
			var node_from_scene = get_tree().current_scene.get_node_or_null(np) as Node2D
			if is_instance_valid(node_from_scene):
				return node_from_scene
		
		if get_tree() and get_tree().root:
			var direct_node = get_tree().root.get_node_or_null(np) as Node2D
			if is_instance_valid(direct_node):
				return direct_node
	return null

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
	var camera = get_tree().get_first_node_in_group("main_camera")
	if camera:
		camera.clear_focus_target()
	
	is_active = false
	_current_npc = null
	_camera_shots.clear()
	panel.hide()
	dialogue_finished.emit()
