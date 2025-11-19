extends Area2D

signal destroyed
@export var explosion_scene: PackedScene

const WarningScene = preload("res://HitboxIndicator.tscn")
var warning_indicator = null

var is_falling = false
const GRAVITY = 980.0
var velocity = Vector2.ZERO

func _ready():
	$Sprite2D.light_mask = 1
	$AnimationPlayer.play("blink")
	if explosion_scene == null:
		explosion_scene = load("res://stalactiteExplosion.tscn")

func explode():
	if is_instance_valid(warning_indicator):
		warning_indicator.queue_free()
		
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	queue_free()

func _physics_process(delta):
	if is_falling:
		velocity.y += GRAVITY * delta
		global_position += velocity * delta

func _on_body_entered(body):
	# If a bullet hits the stalactite, the bullet should explode.
	if body.is_in_group("bullets"):
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

	# If we are already falling, check for impact
	if is_falling:
		# Check if we hit the boss or player to deal damage
		if body.is_in_group("boss") or body.is_in_group("player"):
			if body.has_method("take_damage"):
				# In the design doc, stalactites deal 20 damage to the boss.
				body.take_damage(40)
		
		# Explode on impact with any physics body (boss, player, world)
		emit_signal("destroyed")
		explode()
		return # Stop further processing

	# If we are not falling, we only care about player bullets.
	# Note: The collision mask is already set to only detect player_bullets in the scene file.
	start_fall()

func _on_area_entered(area):
	# This is now only for special Area2D-based interactions, if any.
	# The main damage logic for falling is handled in _on_body_entered.
	pass

func start_fall():
	if is_falling: return # Prevent re-triggering

	# --- Spawn Warning Indicator ---
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 2000))
	query.collision_mask = 1 # "world" layer
	var result = space_state.intersect_ray(query)
	
	if result:
		warning_indicator = WarningScene.instantiate()
		get_tree().root.add_child(warning_indicator)
		warning_indicator.global_position = result.position
		
		# Disable the auto-destruct timer
		warning_indicator.get_node("Timer").stop()
		
		# Set size to match stalactite
		var sprite_width = 0.0
		if $Sprite2D.texture:
			sprite_width = $Sprite2D.texture.get_width() * $Sprite2D.scale.x
			warning_indicator.set_radius(sprite_width * 1.5)
		
		# Position adjustment to sit ON TOP of the ground
		var visual_node = warning_indicator.get_node("Sprite2D")
		if visual_node and visual_node.texture:
			var half_height = visual_node.texture.get_height() * visual_node.scale.y / 2.0
			warning_indicator.global_position.y -= half_height

	# --- End Spawn Warning ---

	# Stop monitoring to prevent multiple bullet hits during animation
	monitoring = false
	
	var tween = create_tween().set_loops(2)
	tween.tween_property($Sprite2D, "modulate", Color.RED, 0.25)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.25)
	await tween.finished
	
	is_falling = true
	velocity = Vector2.ZERO # Reset velocity before falling
	
	# Start monitoring again to detect floor/player/boss
	monitoring = true


func _on_screen_exited():
	if is_falling:
		if is_instance_valid(warning_indicator):
			warning_indicator.queue_free()
		emit_signal("destroyed")
		queue_free()

# We no longer need this, the destroyed signal is handled by _on_body_entered
#func _on_respawn_timer_timeout():
#	pass
