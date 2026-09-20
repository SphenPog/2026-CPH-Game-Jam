extends Node2D

@onready var mesh_node: Node2D = $"../QMeshAdvancedNode"
@onready var player_node: Node2D = get_parent() as Node2D

func _physics_process(_delta: float) -> void:
	var calculated_center: Vector2 = Vector2.ZERO
	var found_particles: bool = false

	if is_instance_valid(mesh_node):
		# Method A: Direct get_particles() on QMeshAdvancedNode
		if mesh_node.has_method("get_particles"):
			var particles = mesh_node.call("get_particles")
			calculated_center = _get_center_from_particles(particles)
			if calculated_center != Vector2.ZERO:
				global_position = calculated_center
				return

		# Method B: Get inner QMesh object first -> get_particles()
		if mesh_node.has_method("get_mesh"):
			var qmesh = mesh_node.call("get_mesh")
			if qmesh and qmesh.has_method("get_particles"):
				var particles = qmesh.call("get_particles")
				calculated_center = _get_center_from_particles(particles)
				if calculated_center != Vector2.ZERO:
					global_position = calculated_center
					return

		# Method C: Query QBody via parent Player
		if player_node and player_node.has_method("get_body"):
			var qbody = player_node.call("get_body")
			if qbody and qbody.has_method("get_particles"):
				var particles = qbody.call("get_particles")
				calculated_center = _get_center_from_particles(particles)
				if calculated_center != Vector2.ZERO:
					global_position = calculated_center
					return

	# Fallback: Print warning if no method worked
	print_once_warning()

func _get_center_from_particles(particles) -> Vector2:
	if not (particles is Array) or particles.size() == 0:
		return Vector2.ZERO
		
	var sum_pos: Vector2 = Vector2.ZERO
	var count: int = 0
	
	for p in particles:
		if p is Object:
			if p.has_method("get_global_position"):
				sum_pos += p.call("get_global_position")
				count += 1
			elif p.has_method("get_position"):
				# Convert local particle position to global using mesh_node
				var loc_pos = p.call("get_position")
				sum_pos += mesh_node.to_global(loc_pos) if is_instance_valid(mesh_node) else loc_pos
				count += 1
		elif typeof(p) == TYPE_VECTOR2:
			sum_pos += mesh_node.to_global(p) if is_instance_valid(mesh_node) else p
			count += 1

	return sum_pos / count if count > 0 else Vector2.ZERO

var _warned: bool = false
func print_once_warning() -> void:
	if not _warned:
		print("WARNING: Could not fetch particle positions from QuarkPhysics node!")
		_warned = true
