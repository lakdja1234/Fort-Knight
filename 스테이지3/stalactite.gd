extends Area2D

signal destroyed
@export var explosion_scene: PackedScene

var is_falling = false
const GRAVITY = 980.0
var velocity = Vector2.ZERO

func _ready():
	$Sprite2D.light_mask = 1
	$AnimationPlayer.play("blink")
	if explosion_scene == null:
		explosion_scene = load("res://explosion.tscn")

func explode():
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
				body.take_damage(20)
		
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
		emit_signal("destroyed")
		queue_free()

# We no longer need this, the destroyed signal is handled by _on_body_entered
#func _on_respawn_timer_timeout():
#	pass
