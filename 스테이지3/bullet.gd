# Bullet.gd
extends RigidBody2D

@onready var light = $PointLight2D
@onready var collision_enable_timer = $CollisionEnableTimer
@onready var collision_shape = $CollisionShape2D

var can_collide = false
var owner_node: Node = null
var explosion_scene: PackedScene
var explosion_radius: float = 80.0 # 기본 폭발 반경

func set_explosion_radius(radius: float):
	explosion_radius = radius

func _ready():
	# Always load the explosion scene from the project
	explosion_scene = load("res://스테이지3/explosion.tscn")

	add_to_group("bullets")
	collision_shape.disabled = true
	collision_enable_timer.start()

func _physics_process(delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	if not can_collide or (owner_node and body == owner_node):
		return

	if body.has_method("take_damage"):
		body.take_damage(10)

	explode()

func explode():
	if is_queued_for_deletion():
		return

	remove_from_group("bullets")

	if light:
		var light_global_pos = light.global_position
		var main_scene = get_tree().root
		light.get_parent().remove_child(light)
		main_scene.add_child(light)
		light.global_position = light_global_pos
		var tween = get_tree().create_tween()
		tween.tween_property(light, "energy", 0.0, 2.0).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(light.queue_free)

	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# CRITICAL: Configure the explosion's damage radius and effects.
		if explosion.has_method("set_radius_and_apply_effects"):
			explosion.call_deferred("set_radius_and_apply_effects", explosion_radius)
			
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	
	queue_free()

func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false
