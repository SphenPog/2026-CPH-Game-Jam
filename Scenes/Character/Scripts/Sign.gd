extends Interactible

@export_multiline var lines: Array[String] = ["It's an old wooden sign.", "The writing has faded."]

func _on_interact(_interactor: Node2D) -> void:
	DialogueUI.show_dialogue("", lines)
