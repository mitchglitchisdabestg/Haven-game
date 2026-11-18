class_name ParticleBurst
extends GPUParticles2D

@export var particle_color: Color = Color.WHITE
@export var emission_direction: Vector3 = Vector3(0.0, -1.0, 0.0)
@export_range(1, 128, 1) var particle_amount: int = 18
@export var particle_speed_min: float = 90.0
@export var particle_speed_max: float = 190.0

func _ready() -> void:
	var burst_material := process_material.duplicate() as ParticleProcessMaterial
	if burst_material == null:
		push_error("Particle burst requires a ParticleProcessMaterial.")
		queue_free()
		return

	burst_material.color = particle_color
	burst_material.direction = emission_direction.normalized()
	burst_material.initial_velocity_min = particle_speed_min
	burst_material.initial_velocity_max = particle_speed_max
	process_material = burst_material
	amount = particle_amount
	one_shot = true
	explosiveness = 1.0
	finished.connect(queue_free)
	emitting = true
