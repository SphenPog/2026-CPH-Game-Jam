extends QSoftBodyNode

@onready var mesh_node: Node = get_node_or_null("QMeshAdvancedNode")

@export var launch_force_multiplier: float = 0.1  # Scales pull distance
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

var _overlay: ArrowOverlay
var _nearby_interactables: Array[Interactible] = []
@onready var interaction_detector: Area2D = $InteractionDetector

#audio
var _charge_sfx_player: AudioStreamPlayer
@export var charge_sfx: AudioStream
@export var launch_sfx: AudioStream
@export var dialogue_sfx: AudioStream

func _ready() -> void:
	_overlay = ArrowOverlay.new()
	_overlay.controller = self
	add_child(_overlay)
	
	# initiate interaction settings
	if DialogueUI:
		DialogueUI.dialogue_finished.connect(_on_dialogue_finished)
		
		DialogueUI.dialogue_started.connect(func(): 
			if is_instance_valid(_charge_sfx_player):
				_charge_sfx_player.stop()
				_charge_sfx_player.queue_free()
				_charge_sfx_player = null
			is_dragging = false
			set_process_unhandled_input(false)
		)
	
	if interaction_detector:
		interaction_detector.top_level = true
		
		interaction_detector.area_entered.connect(_on_interaction_area_entered)
		interaction_detector.area_exited.connect(_on_interaction_area_exited)
	
	DialogueUI.dialogue_finished.connect(func(): set_process_unhandled_input(true))

## input from player
func _unhandled_input(event: InputEvent) -> void:
	# interaction key
	if DialogueUI.is_active:
		return

	if event.is_action_pressed("interact"):
		_try_interact()
	
	# mouse movement for flinging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_surface_normal()
			is_dragging = true
			charge_timer = 0.0
			drag_start_pos = get_viewport().get_mouse_position()
			current_drag_pos = drag_start_pos
			
			if charge_sfx:
				_charge_sfx_player = AudioManager.play_sfx(charge_sfx)
			
			_redraw_overlay()
		elif is_dragging:
			is_dragging = false
			
			#stop charge SFX
			if is_instance_valid(_charge_sfx_player):
				_charge_sfx_player.stop()
				_charge_sfx_player.queue_free()
				_charge_sfx_player = null
			
			_launch_softbody()
			_redraw_overlay()
	elif event is InputEventMouseMotion and is_dragging:
		current_drag_pos = get_viewport().get_mouse_position()
		_redraw_overlay()

func _redraw_overlay() -> void:
	if _overlay:
		_overlay.queue_redraw()

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

##
##motion applied after dragging
##
func _launch_softbody() -> void:
	var power_ratio: float = _get_combined_power_ratio()
	var drag_vector = _get_constrained_drag_vector()
	
	if drag_vector.length_squared() < 1.0 or power_ratio < 0.01:
		return
	
	var launch_direction = drag_vector.normalized()
	
	var launch_force = launch_direction * (max_drag_distance * launch_force_multiplier * power_ratio)
	
	if has_method("apply_force"):
		call("apply_force", launch_force)
	
	if launch_sfx:
			AudioManager.play_sfx(launch_sfx, 1.0 + (power_ratio * 0.3))

func _get_current_allowed_max_distance() -> float:
	var charge_ratio = charge_timer / charge_time_sec
	return lerp(min_drag_distance, max_drag_distance, charge_ratio)

func _process(delta: float) -> void:
	if is_dragging:
		if charge_timer < charge_time_sec:
			charge_timer = min(charge_timer + delta, charge_time_sec)
		_redraw_overlay()
	
	_update_interaction_detector_position()

func _update_interaction_detector_position() -> void:
	if interaction_detector:
		if has_method("get_aabb"):
			interaction_detector.global_position = get_aabb().get_center()
		else:
			interaction_detector.global_position = global_position

##
## ground and launch arc detection
##
var current_surface_normal: Vector2 = Vector2.UP
var is_grounded: bool = false

func _update_surface_normal() -> void:
	var space_state = get_world_2d().direct_space_state
	
	var ray_origin: Vector2 = get_aabb().get_center() if has_method("get_aabb") else global_position
	var ray_length: float = 30.0
	var query = PhysicsRayQueryParameters2D.create(
		ray_origin,
		ray_origin + Vector2.DOWN * ray_length
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

##
## collision effects
##
func _on_collision(info: Dictionary) -> bool:
	var slime_component = get_node_or_null("SlimeTrailC")
	if slime_component and slime_component.has_method("handle_collision"):
		slime_component.handle_collision(info)

	var impact_fx = get_node_or_null("ImpactEffect")
	if impact_fx and impact_fx.has_method("handle_collision"):
		impact_fx.handle_collision(info)
		
	return true

##
## Dialogue section
##
func _try_interact() -> void:
	_nearby_interactables = _nearby_interactables.filter(func(item): return is_instance_valid(item))
	
	if not _nearby_interactables.is_empty():
		var target = _nearby_interactables[0]
		target.interact(self)
		
		if dialogue_sfx:
			AudioManager.play_sfx(dialogue_sfx)

func _on_interaction_area_entered(area: Area2D) -> void:
	if area is Interactible and area.is_interactable:
		if not _nearby_interactables.has(area):
			_nearby_interactables.append(area)
			if not DialogueUI.is_active:
				area.show_prompt()

func _on_interaction_area_exited(area: Area2D) -> void:
	if area is Interactible:
		_nearby_interactables.erase(area)
		area.hide_prompt()

func _on_dialogue_finished() -> void:
	refresh_interaction_prompts()

func refresh_interaction_prompts() -> void:
	if not interaction_detector:
		return

	_nearby_interactables.clear()
	var overlapping = interaction_detector.get_overlapping_areas()

	for area in overlapping:
		if area is Interactible and area.is_interactable:
			_nearby_interactables.append(area)
			if not DialogueUI.is_active:
				area.show_prompt()

## 
## arrow class for fling visual
##
class ArrowOverlay extends Node2D:
	var controller: Node

	func _ready() -> void:
		top_level = true
		z_index = 100
		z_as_relative = false

	func _draw() -> void:
		if not controller or not controller.is_dragging:
			return

		var inv_transform = get_global_transform_with_canvas().affine_inverse()
		var local_start = inv_transform * controller.drag_start_pos

		var raw_mouse_distance = (controller.drag_start_pos - controller.current_drag_pos).length()
		if raw_mouse_distance < 3.0:
			return

		var constrained_vector = controller._get_constrained_drag_vector()
		if constrained_vector.length() < 3.0:
			return

		var power_ratio = controller._get_combined_power_ratio()
		var visual_length = controller.max_drag_distance * power_ratio

		var launch_dir_normalized = constrained_vector.normalized()
		var pull_dir_normalized = -launch_dir_normalized

		var local_current = local_start + (pull_dir_normalized * visual_length)

		var allowed_max_dist = controller._get_current_allowed_max_distance()
		var current_distance = min(raw_mouse_distance, allowed_max_dist)

		var shape_color: Color
		if power_ratio < 0.5:
			shape_color = Color.GREEN.lerp(Color.YELLOW, power_ratio * 2.0)
		else:
			shape_color = Color.YELLOW.lerp(Color.RED, (power_ratio - 0.5) * 2.0)

		var fill_color = shape_color
		fill_color.a = lerp(controller.min_alpha, controller.max_alpha, power_ratio)

		var dir_normalized = (local_current - local_start).normalized()

		if power_ratio > 0.5:
			var red_intensity = (power_ratio - 0.5) * 2.0
			var time_offset = sin(Time.get_ticks_msec() * 0.05) * 0.5
			var jitter = randf_range(-0.5, 0.5)
			var shake_angle = deg_to_rad((time_offset + jitter) * controller.max_shake_angle_deg * red_intensity)
			dir_normalized = dir_normalized.rotated(shake_angle)
			local_current = local_start + (dir_normalized * current_distance)
			var camera = get_viewport().get_camera_2d()
			if camera and camera.has_method("add_shake"):
				camera.add_shake(power_ratio)

		var perpendicular = Vector2(-dir_normalized.y, dir_normalized.x) * (controller.triangle_base_width * power_ratio)

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
		var launch_tip = local_start + (launch_dir / 8.0)

		var launch_points = PackedVector2Array([base_left + (1.2 * perpendicular), launch_tip, base_right - (1.2 * perpendicular)])
		draw_polygon(launch_points, PackedColorArray([fill_color]))
