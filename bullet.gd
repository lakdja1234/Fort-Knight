# Bullet.gd
extends RigidBody2D

@export var explosion_scene: PackedScene
# ⚠️ 1. @onready 변수 추가
@onready var light = $PointLight2D


func _physics_process(delta):
	rotation = linear_velocity.angle()


func _on_screen_exited():
	queue_free()


func _on_body_entered(body):
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
	queue_free()

# ⚠️ 2. timeout 함수 추가
func _on_light_timer_timeout():
	# 2초가 지나면 빛(Light)만 끈다.
	if light:
		light.enabled = false
