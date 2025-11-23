# cluster_shell.gd
# This is the main projectile for the cluster attack.
# It flies in an arc, and then splits into three sub-munitions aimed at specific targets.

extends RigidBody2D

# The scene for the smaller projectiles that spawn from this one.
@export var submunition_scene: PackedScene

# The target positions for the sub-munitions, set by the boss.
var target_positions: Array = []

@onready var split_timer = $SplitTimer

func _ready():
	# The shell itself should not collide with anything.
	# It only exists to split in the air.
	collision_mask = 0
	
	# Start the timer that will trigger the split.
	split_timer.start()

func _physics_process(delta):
	# Rotate the shell to face its flight direction.
	rotation = linear_velocity.angle()

func _on_split_timer_timeout():
	split()

func split():
	if is_queued_for_deletion():
		return
		
	if submunition_scene == null:
		printerr("ClusterShell: submunition_scene is not set!")
		queue_free()
		return

	if target_positions.size() != 3:
		printerr("ClusterShell: target_positions were not set correctly!")
		queue_free()
		return

	print("Cluster shell splitting and aiming at targets!")

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var submunition_speed = 600.0 # Speed for the smaller projectiles

	# Create three sub-munitions, each aimed at a specific target
	for i in range(3):
		var submunition = submunition_scene.instantiate()
		get_parent().add_child(submunition)
		submunition.global_position = self.global_position
		
		# Calculate the precise velocity to hit the target position
		var target_pos = target_positions[i]
		var initial_velocity = calculate_parabolic_velocity(self.global_position, target_pos, submunition_speed, gravity)
		submunition.linear_velocity = initial_velocity

	# Remove the main cluster shell
	queue_free()

# Copied from Stage1boss.gd to calculate trajectories for sub-munitions
func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	var delta_y = -delta.y

	if abs(delta_x) < 0.1:
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		var fallback_angle = deg_to_rad(45.0)
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed)

	var actual_launch_speed = max(desired_speed, min_launch_speed)
	var actual_speed_sq = actual_launch_speed * actual_launch_speed

	var gx = gravity * delta_x
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)

	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed
	var vel_y_godot = -vel_y_math

	var initial_velocity = Vector2(vel_x, vel_y_godot)
	return initial_velocity
