extends Node

@export var slime_stamp_scene: PackedScene
@export var min_step_distance: float = 10.0
@export var stamp_lifetime: float = 4.0
@export var slime_color: Color = Color("38e052a0")   # Slime puddle color and transparency
@export var stamp_scale: Vector2 = Vector2(1.2, 0.4)

var _last_stamp_pos: Vector2 = Vector2.INF
var _trail_container: Node2D

func _ready() -> void:
	# Dedicated world container keeps slime attached to the level background
	_trail_container = get_tree().root.get_node_or_null("SlimeTrail") as Node2D
	if not _trail_container:
		_trail_container = Node2D.new()
		_trail_container.name = "SlimeTrail"
		get_tree().root.call_deferred("add_child", _trail_container)

func handle_collision(info: Dictionary) -> void:
	var contact_pos: Vector2 = info.get("position", Vector2.ZERO)
	var contact_normal: Vector2 = info.get("normal", Vector2.UP)

	if contact_pos == Vector2.ZERO and info.has("contacts") and info["contacts"].size() > 0:
		var first_contact = info["contacts"][0]
		contact_pos = first_contact.get("position", Vector2.ZERO)
		contact_normal = first_contact.get("normal", Vector2.UP)

	if contact_pos == Vector2.ZERO:
		return

	if _last_stamp_pos != Vector2.INF and contact_pos.distance_to(_last_stamp_pos) < min_step_distance:
		return

	_spawn_slime_stamp(contact_pos, contact_normal)
	_last_stamp_pos = contact_pos

func _spawn_slime_stamp(pos: Vector2, normal: Vector2) -> void:
	var stamp: Node2D

	if slime_stamp_scene:
		stamp = slime_stamp_scene.instantiate() as Node2D
	else:
		stamp = _create_procedural_stamp()

	_trail_container.add_child(stamp)
	stamp.global_position = pos
	stamp.rotation = normal.angle() + PI / 2.0
	stamp.scale = stamp_scale

	var tween = stamp.create_tween()
	tween.tween_property(stamp, "modulate:a", 0.0, stamp_lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(stamp.queue_free)

func _create_procedural_stamp() -> Node2D:
	var poly = Polygon2D.new()
	var radius: float = 8.0
	var points = PackedVector2Array()
	var num_points: int = 10
	
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		var r = radius * randf_range(0.7, 1.2)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	
	poly.polygon = points
	poly.color = slime_color
	return poly
