# burstplayer.gd
# A player-usable projectile that bursts into smaller bullets on impact.
extends RigidBody2D

@export var submunition_scene: PackedScene
@export var explosion_scene: PackedScene
@export var damage: int = 15

@onready var collision_shape = $CollisionShape2D

func _ready():
	# Set collision properties for a player projectile
	self.collision_layer = 4   # Layer 3: player_bullet
	self.collision_mask = 105  # Collide with world, boss, hazard, boss_gimmick
	
	if submunition_scene == null:
		printerr("BurstPlayer: submunition_scene is not set!")
	if explosion_scene == null:
		printerr("BurstPlayer: explosion_scene is not set!")

func _physics_process(delta):
	rotation = linear_velocity.angle()

func _on_body_entered(body):
	# Apply direct impact damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Trigger the burst effect
	burst()

func burst():
	if is_queued_for_deletion():
		return

	# --- Submunition Spawning ---
	if submunition_scene:
		var submunition_speed = 600.0
		var spread_angles = [-15.0, 0.0, 15.0] # A tighter spread than the cluster bomb
		var base_angle = self.linear_velocity.angle()

		for angle_offset in spread_angles:
			var submunition = submunition_scene.instantiate()
			get_tree().current_scene.add_child(submunition)
			submunition.global_position = self.global_position

			# Configure submunition for the player
			submunition.set_collision_layer(4)
			submunition.set_collision_mask(105)
			
			# Give each submunition its velocity
			var fire_angle_rad = base_angle + deg_to_rad(angle_offset)
			submunition.linear_velocity = Vector2.RIGHT.rotated(fire_angle_rad) * submunition_speed
	
	# --- Main Explosion ---
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		if explosion.has_method("set_radius_and_apply_effects"):
			explosion.call_deferred("set_radius_and_apply_effects", 80.0)
		get_tree().current_scene.add_child(explosion)
		explosion.global_position = self.global_position

	queue_free()

func _on_screen_exited():
	queue_free()
