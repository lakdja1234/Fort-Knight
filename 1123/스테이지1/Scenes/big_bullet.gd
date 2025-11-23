# BigBullet.gd

extends RigidBody2D

@export var explosion_scene: PackedScene
@onready var collision_shape = $CollisionShape2D
@onready var collision_enable_timer = $CollisionEnableTimer

var can_collide = false
var owner_node: Node = null

func _ready():
	if explosion_scene == null:
		printerr("Bullet: explosion_scene was not exported correctly. Loading manually.")
		explosion_scene = load("res://스테이지1/explosion.tscn")

	add_to_group("bullets")
	
	collision_shape.disabled = true # <-- 처음엔 충돌 끔
	collision_enable_timer.start()  # <-- 타이머 시작

func _physics_process(delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	if not can_collide:
		return

	if body.is_in_group("player"):
		body.take_damage(30) 
	
	# On any valid collision (player, ground, etc.), explode.
	explode()

func explode():
	if is_queued_for_deletion():
		return

	remove_from_group("bullets")


	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.scale = Vector2(2.0, 2.0)
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	
	queue_free()

func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false
