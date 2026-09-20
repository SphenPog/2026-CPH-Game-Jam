extends Camera2D

@export var target_softbody: Node2D # Assign your QSoftBodyNode in the Inspector
@export var follow_speed: float = 8.0
@export var debug_mode: bool = true

var _debug_timer: float = 0.0

func _ready() -> void:
	top_level = true 
	make_current()

func _physics_process(delta: float) -> void:
	var should_print: bool = false
	if debug_mode:
		_debug_timer += delta
		if _debug_timer >= 1.0:
			should_print = true
			_debug_timer = 0.0

	if not is_instance_valid(target_softbody):
		if should_print:
			print("[Camera Debug] ERROR: target_softbody is not assigned!")
		return

	var target_pos: Vector2 = Vector2.ZERO
	var method_used: String = "None"

	# 1. Primary Method: Calculate center from active particle AABB bounding box
	if target_softbody.has_method("get_aabb"):
		var aabb: Rect2 = target_softbody.call("get_aabb")
		target_pos = aabb.get_center()
		method_used = "get_aabb().get_center()"

	# 2. Fallback: Query first mesh if get_aabb fails
	if (target_pos == Vector2.ZERO or target_pos == Vector2(466, 204)) and target_softbody.has_method("get_mesh_count"):
		var mesh_count: int = target_softbody.call("get_mesh_count")
		if mesh_count > 0:
			var mesh = target_softbody.call("get_mesh_at", 0)
			if mesh and mesh.has_method("get_global_position"):
				target_pos = mesh.call("get_global_position")
				method_used = "get_mesh_at(0).get_global_position()"

	if should_print:
		print("[Camera Debug] Method: ", method_used, " -> Target Pos: ", target_pos, " | Camera Pos: ", global_position)

	# Smoothly move camera toward active softbody center
	if target_pos != Vector2.ZERO:
		global_position = global_position.lerp(target_pos, follow_speed * delta)
