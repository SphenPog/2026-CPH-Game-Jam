extends Interactible

@export var npc_name: String = "Elder"
@export var headshot: Texture2D
@export_multiline var first_talk_lines: Array[String] = [
	"Greetings, traveler.",
	"Beware of the slippery slime monsters down the road!"
]

@export_multiline var repeat_talk_lines: Array[String] = [
	"Still here? Stay safe near those slime monsters!"
]

@export var line_camera_shots: Dictionary[int, NodePath] = {}

@export_group("Voice Settings")
@export var voice_sfx: AudioStream
@export var voice_pitch: float = 1.0

var interaction_count: int = 0

func _on_interact(_interactor: Node2D) -> void:
	var current_lines: Array[String]
	
	if interaction_count == 0:
		current_lines = first_talk_lines
	else:
		current_lines = repeat_talk_lines
		
	interaction_count += 1
	
	DialogueUI.show_dialogue(npc_name, current_lines, headshot, self, line_camera_shots)
