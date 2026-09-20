# ImpactParticle.gd
extends GPUParticles2D

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	finished.connect(queue_free)
	restart() # Plays exactly ONE burst on frame zero
