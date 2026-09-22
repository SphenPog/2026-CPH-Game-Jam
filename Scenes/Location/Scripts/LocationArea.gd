extends Area2D

@export var location_name: String = "Example Place"
@export var music_track: AudioStream

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_trigger_location()

func _on_area_entered(area: Area2D) -> void:
	if _is_player(area):
		_trigger_location()

func _is_player(node: Node) -> bool:
	if node.is_in_group("player") or node.name == "Player" or node.name == "InteractionDetector":
		return true
	if node.get_parent() and node.get_parent().is_in_group("player"):
		return true
	return false

func _trigger_location() -> void:
	var ui = get_tree().root.get_node_or_null("LocationUI")
	if not ui:
		ui = get_tree().get_first_node_in_group("location_ui")
	if ui and ui.has_method("display_location"):
		ui.display_location(location_name)
		
	var audio = get_tree().root.get_node_or_null("AudioManager")
	if not audio:
		audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and music_track and audio.has_method("play_music"):
		audio.play_music(music_track)
