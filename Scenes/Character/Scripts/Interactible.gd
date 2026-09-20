class_name Interactible
extends Area2D

signal interacted(interactor: Node2D)

@export var prompt_message: String = "[E] Interact"
@export var is_interactable: bool = true
@export var prompt_offset: Vector2 = Vector2(-45, -50)

var _prompt_label: Label

func _ready() -> void:
	_create_prompt_label()

func _create_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = prompt_message
	_prompt_label.position = prompt_offset
	_prompt_label.z_index = 100
	_prompt_label.hide()
	add_child(_prompt_label)

func show_prompt() -> void:
	if is_interactable and _prompt_label:
		_prompt_label.text = prompt_message
		_prompt_label.show()

func hide_prompt() -> void:
	if _prompt_label:
		_prompt_label.hide()

func interact(interactor: Node2D) -> void:
	if not is_interactable:
		return
	hide_prompt()
	interacted.emit(interactor)
	_on_interact(interactor)

func _on_interact(_interactor: Node2D) -> void:
	pass
