# clusterplayer.gd
# Player-usable version of the cluster shell.
# It splits into 3 sub-munitions in a cone.
extends RigidBody2D

# The scene for the smaller bullets that spawn from this shell.
@export var submunition_scene: PackedScene
# The scene for the explosion when the shell itself is destroyed.
@export var explosion_scene: PackedScene

@onready var split_timer = $SplitTimer

func _ready():
	# The player.gd script will set the correct collision layer and mask when firing.
	split_timer.start()

func _physics_process(delta):
	# Keep the shell pointing in the direction it's moving.
	rotation = linear_velocity.angle()

func _on_body_entered(body):
	# When it hits anything, split into smaller projectiles.
	split()

func _on_split_timer_timeout():
	# If the shell hasn't hit anything after a short time, split in mid-air.
	split()

func split():
	# Ensure this logic only runs once.
	if is_queued_for_deletion():
		return

	if submunition_scene == null:
		printerr("ClusterPlayer: submunition_scene is not set!")
		# Fallback to a simple explosion if sub-munitions aren't defined.
		create_explosion()
		queue_free()
		return

	# Define the speed and spread for the sub-munitions.
	var submunition_speed = 700.0
	var spread_angles = [-20.0, 0.0, 20.0] # Angles in degrees relative to the shell's direction.

	# Get the direction the main shell was traveling.
	var base_angle = self.linear_velocity.angle()

	# Create the three sub-munitions.
	for angle_offset in spread_angles:
		var submunition = submunition_scene.instantiate()
		get_tree().current_scene.add_child(submunition)
		submunition.global_position = self.global_position

		# Set the collision properties for a player projectile.
		submunition.set_collision_layer(4) # Layer 3: player_bullet
		submunition.set_collision_mask(105) # Collide with world, boss, hazard, boss_gimmick

		# Calculate the velocity for each sub-munition based on the spread angle.
		var fire_angle_rad = base_angle + deg_to_rad(angle_offset)
		var velocity = Vector2(cos(fire_angle_rad), sin(fire_angle_rad)) * submunition_speed
		submunition.linear_velocity = velocity

	# Create a small explosion for the main shell's impact.
	create_explosion()
	# Remove the main cluster shell.
	queue_free()

func create_explosion():
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_tree().current_scene.add_child(explosion)
		explosion.global_position = self.global_position
