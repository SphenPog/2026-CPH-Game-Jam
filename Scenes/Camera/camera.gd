extends Camera2D

@export var target_player: Node2D
@export var follow_speed: float = 8.0
@export var lead_factor: float = 0.25
@export var max_lead_distance: float = 120.0
@export var shake_intensity_factor: float = 1.0

@export_group("Impact Downward Shove")
@export var min_downward_speed: float = 200.0
@export var impact_threshold: float = 400.0
@export var max_impact_speed_drop: float = 1000.0
@export var max_overshoot_impulse: float = 500.0
@export var spring_stiffness: float = 2.0
@export var spring_damping: float = 1.5

var last_valid_position: Vector2 = Vector2.ZERO
var previous_speed: Vector2 = Vector2.ZERO

var shake_intensity: float = 0.0
var impact_offset: Vector2 = Vector2.ZERO
var impact_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	make_current()
	top_level = true
	
	if not target_player and get_parent() is Node2D and get_parent() != get_tree().root:
		target_player = get_parent() as Node2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		return
	
	var current_pos: Vector2 = Vector2.ZERO
	
	if target_player.has_method("get_aabb"):
		var aabb: Rect2 = target_player.call("get_aabb")
		current_pos = aabb.get_center()
	
	if current_pos == Vector2.ZERO:
		if last_valid_position != Vector2.ZERO:
			current_pos = last_valid_position
		else:
			return
	
	if last_valid_position == Vector2.ZERO:
		last_valid_position = current_pos
	
	#Velocity and Speed
	var velocity: Vector2 = (current_pos - last_valid_position) / max(delta, 0.001)
	
	#impact Detection
	if previous_speed.y > min_downward_speed:
		var vertical_speed_drop: float = previous_speed.y - velocity.y
		
		if vertical_speed_drop > impact_threshold:
			var impact_ratio: float = clamp(
				(vertical_speed_drop - impact_threshold) / max(max_impact_speed_drop - impact_threshold, 1.0),
				0.0,
				1.0
			)
			# Push the spring downward smoothly with an impulse
			impact_velocity.y += max_overshoot_impulse * impact_ratio
	
	previous_speed = velocity
	last_valid_position = current_pos
	
	var offset_target: Vector2 = velocity * lead_factor
	if offset_target.length() > max_lead_distance:
		offset_target = offset_target.normalized() * max_lead_distance
	
	var final_target: Vector2 = current_pos + offset_target
	global_position = global_position.lerp(final_target, follow_speed * delta)

func _process(delta: float) -> void:
	var spring_force: Vector2 = -spring_stiffness * impact_offset
	var damping_force: Vector2 = -spring_damping * impact_velocity
	impact_velocity += (spring_force + damping_force) * delta
	impact_offset += impact_velocity * delta
	
	var jitter_offset = Vector2.ZERO
	if shake_intensity > 0.0:
		jitter_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = move_toward(shake_intensity, 0.0, delta * 35.0)
	
	offset = jitter_offset + impact_offset

func add_shake(ratio: float) -> void:
	var new_shake = clamp(ratio, 0.0, 1.0) * shake_intensity_factor
	shake_intensity = max(shake_intensity, new_shake)
