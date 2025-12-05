# Bullet.gd
extends RigidBody2D

@onready var light = $PointLight2D
@onready var collision_enable_timer = $CollisionEnableTimer
@onready var collision_shape = $CollisionShape2D

var can_collide = false
var owner_node: Node = null
var explosion_scene: PackedScene # No longer exported, will be loaded in _ready
var is_boss_bullet = false

func _ready():
	# Always load the explosion scene from the project
	explosion_scene = load("res://스테이지3/explosion.tscn")

	add_to_group("player_bullets")
	collision_shape.disabled = true
	collision_enable_timer.start()

func _physics_process(delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	# 충돌이 아직 활성화되지 않았으면 무시
	if not can_collide:
		return
	
	# 충돌 시 무조건 폭발
	explode()

func explode():
	if is_queued_for_deletion():
		return

	# 보스 총알인 경우에만 카메라 흔들림
	if is_boss_bullet:
		var camera = get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("shake"):
			camera.shake(3.5, 0.5)

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
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	
	queue_free()

func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false
