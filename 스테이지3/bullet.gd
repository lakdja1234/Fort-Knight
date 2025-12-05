# Bullet.gd
extends RigidBody2D

@onready var light = $PointLight2D
@onready var collision_enable_timer = $CollisionEnableTimer
@onready var collision_shape = $CollisionShape2D

var can_collide = false
var owner_node: Node = null
var explosion_scene: PackedScene # This will be loaded dynamically in explode()
var explosion_radius: float = 1.0 # Default explosion radius (visual scale)
var current_stage: String = "" # To be set by the player



func _ready():
	add_to_group("bullets")
	collision_shape.disabled = true
	collision_enable_timer.start()

func _physics_process(_delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	if not can_collide or (owner_node and body == owner_node):
		return
	


	# Immediately disable collision to prevent further signals from this bullet
	collision_shape.call_deferred("set", "disabled", true)
	call_deferred("set_contact_monitor", false)
	call_deferred("set_physics_process", false)



	call_deferred("explode")

func explode():
	if is_queued_for_deletion():
		return
	
	# Dynamically decide which explosion to use
	if current_stage.contains("스테이지2"):
		explosion_scene = load("res://스테이지2/explosion.tscn")
	else:
		explosion_scene = load("res://스테이지3/explosion.tscn")

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
		# 모든 폭발 인스턴스에 대해 set_radius를 호출합니다.
		# 각 스테이지의 explosion.gd 스크립트가 이 값을 다르게 처리합니다.
		if explosion.has_method("set_radius"):
			explosion.set_radius(explosion_radius)
	
	queue_free()

# Called by the player to inform the bullet of the current stage
func set_current_stage(stage_name: String):
	self.current_stage = stage_name

func set_explosion_radius(radius: float):
	self.explosion_radius = radius

func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false

# Called by Player script to resize the bullet
func set_projectile_scale(new_scale: Vector2):
	var sprite = $Sprite2D
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale
