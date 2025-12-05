extends Node2D

# --- EXPORTED VARIABLES ---
@export var explosion_radius: float = 80.0
@export var damage: int = 10

# --- NODE REFERENCES ---
@onready var animated_explosion: AnimatedSprite2D = $AnimatedExplosion

# Base radius of the default animation/shape
const BASE_RADIUS = 80.0

func _ready():
	# Play the animation, which is the only thing the explosion should do on its own.
	animated_explosion.animation_finished.connect(_on_animation_finished)
	animated_explosion.play("explode")

# This function is called deferred to avoid changing physics state during the wrong time.
func set_radius_and_apply_effects(new_radius: float):
	# Get nodes just-in-time to be more robust
	var damage_area: Area2D = get_node_or_null("DamageArea")
	if not damage_area:
		printerr("Explosion: Could not find DamageArea node!")
		return
		
	var damage_shape: CollisionShape2D = damage_area.get_node_or_null("CollisionShape2D")
	if not damage_shape:
		printerr("Explosion: Could not find CollisionShape2D node!")
		return

	# Connect the signal BEFORE setting the shape to ensure no missed frames.
	damage_area.body_entered.connect(_on_damage_area_body_entered)

	self.explosion_radius = new_radius
	
	# Update the collision shape for damage
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	damage_shape.shape = shape
	
	# Update the visual scale of the animation
	var scale_factor = explosion_radius / BASE_RADIUS
	animated_explosion.scale = Vector2(scale_factor, scale_factor)

	# Shake camera, proportional to the explosion size
	var shake_strength = clamp(inverse_lerp(40.0, 240.0, explosion_radius), 0.5, 2.0) * 15.0
	GlobalSignals.camera_shake_requested.emit(shake_strength, 0.3)

# NEW: Event-driven damage function
func _on_damage_area_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)

func _on_animation_finished():
	# Wait a very short moment before disappearing to ensure all collision signals can be processed.
	await get_tree().create_timer(0.1).timeout
	queue_free()
