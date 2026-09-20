extends Node

@export var slime_decal_scene: PackedScene
@export var trail_spacing: float = 12.0

@onready var parent_softbody: QSoftBodyNode = get_parent() as QSoftBodyNode
var _last_trail_pos: Vector2 = Vector2(INF, INF)

func _ready() -> void:
	if not parent_softbody:
		set_physics_process(false)

func handle_collision(info: Dictionary) -> void:
	var contact_pos: Vector2 = info.get("position", Vector2.ZERO)
	var contact_normal: Vector2 = info.get("normal", Vector2.UP)

	if contact_pos == Vector2.ZERO and info.has("contacts") and info["contacts"].size() > 0:
		contact_pos = info["contacts"][0].get("position", Vector2.ZERO)
		contact_normal = info["contacts"][0].get("normal", Vector2.UP)

	if contact_pos != Vector2.ZERO and _last_trail_pos.distance_to(contact_pos) >= trail_spacing:
		_spawn_decal(contact_pos, contact_normal)
		_last_trail_pos = contact_pos

func _spawn_decal(pos: Vector2, normal: Vector2) -> void:
	if not slime_decal_scene:
		return
	var decal = slime_decal_scene.instantiate() as Node2D
	get_tree().root.add_child(decal)
	decal.global_position = pos
	decal.rotation = normal.angle() + PI / 2.0
