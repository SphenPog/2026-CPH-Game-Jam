extends Interactible

@export var npc_name: String = "Elder"
@export var headshot: Texture2D
@export_multiline var lines: Array[String] = [
	"Greetings, traveler.",
	"Beware of the slippery slime monsters down the road!"
]

func _on_interact(_interactor: Node2D) -> void:
	DialogueUI.show_dialogue(npc_name, lines, headshot)
