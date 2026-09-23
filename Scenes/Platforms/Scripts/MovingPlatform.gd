extends QRigidBodyNode

@export_group("Visuals")
@export var sprite_node: Node2D # Drag your Sprite2D or visual node here

@export_group("Platform Motion")
@export var target_offset: Vector2 = Vector2(200, 0)
@export var travel_time: float = 2.0
@export var pause_duration: float = 0.5
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Behavior")
@export var auto_start: bool = true

var _start_position: Vector2
var _tween: Tween

func _ready() -> void:
	_start_position = global_position
	
	# Enable kinematic mode via Quark's native method instead of property dictionaries
	if has_method("set_kinematic_enabled"):
		set_kinematic_enabled(true)

	if auto_start:
		start_moving()

func start_moving() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	var target_position = _start_position + target_offset

	# Bind Tween step to Physics Process loop
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_loops().set_trans(trans_type).set_ease(ease_type)

	# Leg 1: Forward
	_tween.tween_callback(func(): _set_sprite_flipped(false))
	_tween.tween_method(_move_and_sync_quark_mesh, _start_position, target_position, travel_time)
	_tween.tween_interval(pause_duration)

	# Leg 2: Return
	_tween.tween_callback(func(): _set_sprite_flipped(true))
	_tween.tween_method(_move_and_sync_quark_mesh, target_position, _start_position, travel_time)
	_tween.tween_interval(pause_duration)

# Use Quark's native position and collision setter method
func _move_and_sync_quark_mesh(new_pos: Vector2) -> void:
	if has_method("set_body_position_and_collide"):
		set_body_position_and_collide(new_pos, false)
	else:
		global_position = new_pos
	
	# Keep visual sprite aligned with the physics body
	if sprite_node:
		sprite_node.global_position = new_pos

func stop_moving() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

func _set_sprite_flipped(flipped: bool) -> void:
	var sprite = sprite_node if sprite_node else get_node_or_null("Sprite2D")
	if sprite and "flip_h" in sprite:
		sprite.flip_h = flipped
	elif sprite_node:
		sprite_node.scale.x = -1.0 if flipped else 1.0
