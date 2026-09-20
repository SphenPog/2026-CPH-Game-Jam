extends Node

@export var impact_particle_scene: PackedScene
@export var min_impact_speed: float = 120.0 
@export var cooldown_msec: int = 400

var _last_spawn_time: int = 0
var _prev_pos: Vector2 = Vector2.ZERO
var _current_speed: float = 0.0
var _last_frame_speed: float = 0.0

@onready var parent_softbody: Node2D = get_parent() as Node2D

func _physics_process(delta: float) -> void:
	if not parent_softbody or delta <= 0.0:
		return

	var current_pos: Vector2 = _get_player_center()
	if _prev_pos != Vector2.ZERO:
		_last_frame_speed = _current_speed
		_current_speed = (current_pos - _prev_pos).length() / delta

	_prev_pos = current_pos

func handle_collision(info: Dictionary) -> void:
	if not impact_particle_scene:
		return

	var current_time: int = Time.get_ticks_msec()
	if current_time - _last_spawn_time < cooldown_msec:
		return

	var impact_speed: float = max(_current_speed, _last_frame_speed)

	if impact_speed < min_impact_speed:
		return

	var contact_normal: Vector2 = info.get("normal", Vector2.UP)
	if contact_normal == Vector2.ZERO and info.has("contacts") and info["contacts"].size() > 0:
		contact_normal = info["contacts"][0].get("normal", Vector2.UP)

	var spawn_pos: Vector2 = _get_player_bottom_center()
	if spawn_pos == Vector2.ZERO:
		return

	_last_spawn_time = current_time
	_spawn_effect(spawn_pos, contact_normal)

func _get_player_center() -> Vector2:
	if parent_softbody and parent_softbody.has_method("get_aabb"):
		return parent_softbody.get_aabb().get_center()
	elif parent_softbody:
		return parent_softbody.global_position
	return Vector2.ZERO

func _get_player_bottom_center() -> Vector2:
	if parent_softbody and parent_softbody.has_method("get_aabb"):
		var aabb: Rect2 = parent_softbody.get_aabb()
		return Vector2(aabb.get_center().x, aabb.end.y)
	elif parent_softbody:
		return parent_softbody.global_position
	return Vector2.ZERO

func _spawn_effect(pos: Vector2, normal: Vector2) -> void:
	var effect = impact_particle_scene.instantiate() as Node2D
	get_tree().root.add_child(effect)
	effect.global_position = pos
	effect.rotation = normal.angle() + PI / 2.0
