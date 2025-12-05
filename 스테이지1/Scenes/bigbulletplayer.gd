# bigbulletplayer.gd - CORRECTED VERSION
# Player-usable version of the big bullet.

extends RigidBody2D

# Note: The explosion_scene is not exported and loaded manually in _ready()
# to prevent scene linking issues.
@export var damage: int = 40 # Increased damage for a "big" bullet feel

var explosion_scene: PackedScene

@onready var collision_shape = $CollisionShape2D

func _ready():
	# Load the correct explosion scene directly
	explosion_scene = load("res://스테이지1/explosion.tscn")
	if explosion_scene == null:
		printerr("BigBulletPlayer: CRITICAL - FAILED to load explosion_scene at res://스테이지1/explosion.tscn")
		return

	# Set the collision properties for a player-fired projectile.
	self.collision_layer = 4   # Layer 3: player_bullet
	self.collision_mask = 105  # Collide with world, boss, hazard, boss_gimmick

func _physics_process(delta):
	# Point in the direction of movement
	rotation = linear_velocity.angle()

func _on_body_entered(body):
	# Check if the collided body can take damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# On any valid collision, explode.
	explode()

func explode():
	if is_queued_for_deletion():
		return

	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# Set the radius for the explosion. 120.0 is a good size for a "big" bullet.
		if explosion.has_method("set_radius_and_apply_effects"):
			explosion.call_deferred("set_radius_and_apply_effects", 120.0)
		
		explosion.global_position = self.global_position
		
		# Safely get a parent to add the child to.
		var parent = get_parent()
		if parent:
			parent.add_child(explosion)
		else:
			get_tree().root.add_child(explosion)
	
	queue_free()

func _on_screen_exited():
	# Clean up the bullet if it goes off-screen
	queue_free()
