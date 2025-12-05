# Bullet.gd
extends RigidBody2D

@export var explosion_scene: PackedScene
@onready var collision_enable_timer = $CollisionEnableTimer
@onready var collision_shape = $CollisionShape2D

var can_collide = false
var owner_node: Node = null
var explosion_radius: float = 80.0

func set_explosion_radius(radius: float):
	explosion_radius = radius

func _ready():
	if explosion_scene == null:
		printerr("Bullet: CRITICAL - explosion_scene is not assigned in the editor!")
		return

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


	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# 폭발 씬에 반경 값을 지연 호출로 전달합니다.
		if explosion.has_method("set_radius_and_apply_effects"):
			explosion.call_deferred("set_radius_and_apply_effects", explosion_radius)
		
		explosion.global_position = self.global_position
		# 포탄의 부모(보통 get_tree().root)에 폭발을 추가합니다.
		var parent = get_parent()
		if parent:
			parent.add_child(explosion)
		else:
			get_tree().root.add_child(explosion)
	queue_free()

func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false
