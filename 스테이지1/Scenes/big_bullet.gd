class_name BigBullet
extends RigidBody2D

@export var explosion_scene: PackedScene

@onready var collision_enable_timer = $CollisionEnableTimer

var can_collide = false
var owner_node: Node = null
var explosion_radius: float = 320.0 # 보스의 큰 포탄 기본 폭발 반경

# Store original collision settings to prevent editor warnings
var _real_collision_layer: int
var _real_collision_mask: int

# 보스 스크립트에서 이 함수를 호출하여 폭발 반경을 설정합니다.
func set_explosion_radius(radius: float):
	explosion_radius = radius

func _ready():
	if explosion_scene == null:
		printerr("BigBullet: CRITICAL - FAILED to load explosion_scene at res://스테이지1/big_explosion.tscn")
		return

	add_to_group("bullets")
	add_to_group("big_bullets")
	
	# Store the intended layers then temporarily disable collision to avoid hitting the owner
	_real_collision_layer = self.collision_layer
	_real_collision_mask = self.collision_mask
	self.collision_layer = 0
	self.collision_mask = 0
	
	collision_enable_timer.start()

func _physics_process(delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	# Do not collide with owner
	if owner_node and body == owner_node:
		return
	
	# Only explode after the collision timer has finished
	if can_collide:
		explode()

func explode():
	if is_queued_for_deletion():
		return
	queue_free()

	remove_from_group("bullets")
	remove_from_group("big_bullets")

	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# Defer the call to set the radius to avoid physics errors
		if explosion.has_method("set_radius_and_apply_effects"):
			explosion.call_deferred("set_radius_and_apply_effects", explosion_radius)
		
		explosion.global_position = self.global_position

		var parent = get_parent()
		if parent:
			parent.add_child(explosion)
		else:
			get_tree().root.add_child(explosion)

func _on_collision_enable_timer_timeout():
	# Restore collision layers to enable physics interaction
	self.collision_layer = _real_collision_layer
	self.collision_mask = _real_collision_mask
	can_collide = true
