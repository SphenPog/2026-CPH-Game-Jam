class_name WearableInteractible
extends Interactible

@export_file("*.tscn") var target_scene_path: String
@export var speaker_name: String = "Item"
@export_multiline var dialogue_lines: Array[String] = ["You found a curious item.", "What would you like to do?"]
@export var portrait: Texture2D

func _ready() -> void:
	super._ready()

func _on_interact(_interactor: Node2D) -> void:
	DialogueUI.show_dialogue(speaker_name, dialogue_lines, portrait, self)
	
	if not DialogueUI.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueUI.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

func _on_dialogue_finished() -> void:
	_show_choice_prompt()

func _show_choice_prompt() -> void:
	var choice_dialog = AcceptDialog.new()
	choice_dialog.dialog_text = "Do you want to put on the item, or leave it alone? \n          (wearing the item triggers an ending.)"
	choice_dialog.title = "Make a Choice"
	
	choice_dialog.ok_button_text = "Put It On"
	choice_dialog.add_cancel_button("Leave It")
	
	choice_dialog.confirmed.connect(func():
		_put_on_item()
		choice_dialog.queue_free()
	)
	
	choice_dialog.canceled.connect(func():
		_leave_item()
		choice_dialog.queue_free()
	)
	
	get_tree().root.add_child(choice_dialog)
	choice_dialog.popup_centered()

func _put_on_item() -> void:
	if target_scene_path and not target_scene_path.is_empty():
		get_tree().change_scene_to_file(target_scene_path)
	else:
		print("Target scene path is not set for wearing!")

func _leave_item() -> void:
	is_interactable = true
