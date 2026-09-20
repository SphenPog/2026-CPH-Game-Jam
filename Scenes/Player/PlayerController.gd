extends QSoftBodyNode

@onready var mesh_node: Node = get_node_or_null("QMeshAdvancedNode")

@export var launch_force_multiplier: float = 0.1  # Scales pull distance
@export var rotation_force_multiplier: float = 0.1 # Adds slight rotation
@export var triangle_base_width: float = 16 # sets visual indicator base size
@export var min_alpha: float = 0.50 # Transparency when drag starts
@export var max_alpha: float = 0.75  # Transparency at maximum pull distance
@export var max_shake_angle_deg: float = 8.0  # Maximum shake red power

@export var min_drag_distance: float = 30.0    # Initial drag cap when click
@export var max_drag_distance: float = 180.0   # drag cap after 3 seconds of holding
@export var charge_time_sec: float = 3.0

var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var current_drag_pos: Vector2 = Vector2.ZERO
var charge_timer: float = 0.0

func _ready() -> void:
	call_deferred("_init_polygon_points")

func _unhandled_input(event: InputEvent) -> void:
	#dragging click tracking
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_surface_normal()
			is_dragging = true
			charge_timer = 0.0
			drag_start_pos = get_global_mouse_position()
			current_drag_pos = drag_start_pos
			queue_redraw()
		elif is_dragging:
			is_dragging = false
			_launch_softbody()
			queue_redraw()
	elif event is InputEventMouseMotion and is_dragging:
		current_drag_pos = get_global_mouse_position()
		queue_redraw()

func _get_constrained_drag_vector() -> Vector2:
	var raw_drag_vector = drag_start_pos - current_drag_pos
	if raw_drag_vector.length_squared() < 1.0:
		return Vector2.ZERO
	
	var raw_launch_dir = raw_drag_vector.normalized()
	var constrained_launch_dir = _clamp_launch_vector_to_surface(raw_launch_dir, current_surface_normal)
	
	return constrained_launch_dir * raw_drag_vector.length()

func _get_combined_power_ratio() -> float:
	var drag_vector = drag_start_pos - current_drag_pos
	var distance_ratio = clamp(drag_vector.length() / max_drag_distance, 0.0, 1.0)
	var charge_ratio = clamp(charge_timer / charge_time_sec, 0.0, 1.0)
	
	return distance_ratio * charge_ratio

#motion applied after dragging
func _launch_softbody() -> void:
	var power_ratio: float = _get_combined_power_ratio()
	var drag_vector = _get_constrained_drag_vector()
	
	if drag_vector.length_squared() < 1.0 or power_ratio < 0.01:
		return
	
	var launch_direction = drag_vector.normalized()
	
	var launch_force = launch_direction * (max_drag_distance * launch_force_multiplier * power_ratio)
	var rotation_torque = drag_vector.x * rotation_force_multiplier * power_ratio
	
	if has_method("apply_force"):
		call("apply_force", launch_force)

	if has_method("rotate"):
		call("rotate", rotation_torque)

func _get_current_allowed_max_distance() -> float:
	var charge_ratio = charge_timer / charge_time_sec
	return lerp(min_drag_distance, max_drag_distance, charge_ratio)

func _draw() -> void:
	if is_dragging:
		var local_start = to_local(drag_start_pos)
		var constrained_vector = _get_constrained_drag_vector()
		if constrained_vector.length() < 3.0:
			return
		
		var local_current = to_local(current_drag_pos)
		var drag_dir = local_start - local_current
		
		var raw_mouse_distance = drag_dir.length()
		
		if raw_mouse_distance < 3.0:
			return #avoid divide by small floats
		
		var allowed_max_dist = _get_current_allowed_max_distance()
		var current_distance = min(raw_mouse_distance, allowed_max_dist)
		
		var power_ratio: float = _get_combined_power_ratio()
		var visual_length = max_drag_distance * power_ratio
		
		local_current = local_start - (drag_dir.normalized() * visual_length)
		
		var shape_color: Color
		if power_ratio < 0.5:
			shape_color = Color.GREEN.lerp(Color.YELLOW, power_ratio * 2.0)
		
		else:
			shape_color = Color.YELLOW.lerp(Color.RED, (power_ratio - 0.5) * 2.0)
		
		var fill_color = shape_color
		fill_color.a = lerp(min_alpha, max_alpha, power_ratio)
		
		var dir_normalized = (local_current - local_start).normalized()
		
		if power_ratio > 0.5:
			var red_intensity = (power_ratio - 0.5) * 2.0
			var time_offset = sin(Time.get_ticks_msec() * 0.05) * 0.5
			var jitter = randf_range(-0.5, 0.5)
			var shake_angle = deg_to_rad((time_offset + jitter) * max_shake_angle_deg * red_intensity)
			dir_normalized = dir_normalized.rotated(shake_angle)
			local_current = local_start + (dir_normalized * current_distance)
		
		var perpendicular = Vector2(-dir_normalized.y, dir_normalized.x) * (triangle_base_width * power_ratio)
		
		var base_left = local_start + perpendicular
		var base_right = local_start - perpendicular
		var tip = local_current
		
		var triangle_points = PackedVector2Array([base_left, base_right, tip, base_left])
		var triangle_colors = PackedColorArray([fill_color])
		
		draw_polygon(triangle_points, triangle_colors)
		var outline_color = shape_color
		outline_color.a = fill_color.a + 0.25
		draw_polyline(PackedVector2Array([base_left, base_right, tip, base_left]), outline_color, 1.0)
		
		var launch_dir = (local_start - local_current).normalized() * current_distance
		var launch_tip = local_start + (launch_dir/8)
		
		var launch_points = PackedVector2Array([base_left + (1.2 * perpendicular), launch_tip, base_right - (1.2 * perpendicular)])
		draw_polygon(launch_points, PackedColorArray([fill_color]))
		
func _process(delta: float) -> void:
	if is_dragging:
		if charge_timer < charge_time_sec:
			charge_timer = min(charge_timer + delta, charge_time_sec)
		queue_redraw()

#ground and launch arc detection
var current_surface_normal: Vector2 = Vector2.UP
var is_grounded: bool = false

func _update_surface_normal() -> void:
	var space_state = get_world_2d().direct_space_state
	
	var ray_length: float = 30.0
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2.DOWN * ray_length
	)
	var result = space_state.intersect_ray(query)
	
	if result and result.has("normal"):
		is_grounded = true
		current_surface_normal = result.normal
	else:
		is_grounded = false
		current_surface_normal = Vector2.UP

func _clamp_launch_vector_to_surface(launch_dir: Vector2, normal: Vector2) -> Vector2:
	if launch_dir.dot(normal) < 0.0:
		var tangent = Vector2(-normal.y, normal.x)
		
		if launch_dir.dot(tangent) < 0.0:
			tangent = -tangent
			
		return tangent.normalized()
	return launch_dir.normalized()
