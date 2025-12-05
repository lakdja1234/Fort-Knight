extends Node2D

# --- EXPORTED VARIABLES ---
@export var explosion_radius: float = 160.0 # Default for big explosion
@export var damage: int = 20

# --- NODE REFERENCES ---
@onready var animated_explosion: AnimatedSprite2D = $AnimatedExplosion

func _ready():
	# Play the animation. Configuration will be handled by the projectile.
	animated_explosion.animation_finished.connect(_on_animation_finished)
	animated_explosion.play("explode")

# This function is called deferred to avoid changing physics state during the wrong time.
func set_radius_and_apply_effects(new_radius: float):
	# Get nodes just-in-time to be more robust
	var damage_area: Area2D = get_node_or_null("DamageArea")
	if not damage_area:
		printerr("BigExplosion: Could not find DamageArea node!")
		return
		
	var damage_shape: CollisionShape2D = damage_area.get_node_or_null("CollisionShape2D")
	if not damage_shape:
		printerr("BigExplosion: Could not find CollisionShape2D node!")
		return

	self.explosion_radius = new_radius
	
	# Update the collision shape for damage
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	damage_shape.shape = shape
	
	# NOTE: Visual scale is NOT changed from the script. It should be set in the scene.

	# Shake camera, proportional to the explosion size
	var shake_strength = clamp(inverse_lerp(40.0, 240.0, explosion_radius), 0.5, 2.0) * 15.0
	GlobalSignals.camera_shake_requested.emit(shake_strength, 0.3)

	# Apply damage once, after a very short delay for physics to update
	apply_area_damage()

# Finds all damageable bodies within the radius and applies damage
func apply_area_damage():
	# Get node just-in-time
	var damage_area: Area2D = get_node_or_null("DamageArea")
	if not damage_area:
		return # Already logged error in the previous function

	# Wait for the next physics frame for the engine to recognize the new shape size
	await get_tree().physics_frame
	
	var bodies_to_damage = damage_area.get_overlapping_bodies()
	for body in bodies_to_damage:
		if body.has_method("take_damage"):
			body.take_damage(damage)

func _on_animation_finished():
	queue_free()
