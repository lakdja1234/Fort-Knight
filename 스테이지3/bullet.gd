# Bullet.gd (Merged by Gemini)
extends RigidBody2D

@onready var light = $PointLight2D
@onready var collision_enable_timer = $CollisionEnableTimer
@onready var collision_shape = $CollisionShape2D

var can_collide = false
var owner_node: Node = null
var explosion_scene: PackedScene # 폭발 씬은 explode()에서 동적으로 로드됩니다.
var explosion_radius: float = 1.0 # 기본 폭발 반경 (시각적 크기)
var current_stage: String = "" # 플레이어에 의해 설정될 현재 스테이지
var is_boss_bullet = false # 보스가 쏜 총알인지 여부

func _ready():
	# 총알의 종류에 따라 적절한 그룹에 추가합니다.
	if is_boss_bullet:
		add_to_group("boss_bullets")
	else:
		add_to_group("player_bullets")
	add_to_group("bullets") # 모든 총알이 속하는 공통 그룹

	collision_shape.disabled = true
	collision_enable_timer.start()

func _physics_process(_delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free()

func _on_body_entered(body):
	# 충돌 비활성화 상태이거나 자신의 발사체와 충돌한 경우 무시합니다.
	if not can_collide or (owner_node and body == owner_node):
		return

	# 추가적인 충돌 신호를 막기 위해 즉시 충돌을 비활성화합니다.
	collision_shape.call_deferred("set", "disabled", true)
	call_deferred("set_contact_monitor", false)
	call_deferred("set_physics_process", false)

	# 폭발 함수를 호출합니다.
	call_deferred("explode")

func explode():
	if is_queued_for_deletion():
		return
	
	# 현재 스테이지에 따라 적절한 폭발 씬을 동적으로 로드합니다.
	if current_stage.contains("스테이지2"):
		explosion_scene = load("res://스테이지2/explosion.tscn")
	else: # 기본값 또는 스테이지3
		explosion_scene = load("res://스테이지3/explosion.tscn")

	# 보스 총알인 경우에만 카메라를 흔듭니다.
	if is_boss_bullet:
		var camera = get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("shake"):
			camera.shake(3.5, 0.5)

	# 그룹에서 총알을 제거합니다.
	remove_from_group("bullets")
	if is_boss_bullet:
		remove_from_group("boss_bullets")
	else:
		remove_from_group("player_bullets")


	# 빛 효과 처리
	if light:
		var light_global_pos = light.global_position
		var main_scene = get_tree().root
		light.get_parent().remove_child(light)
		main_scene.add_child(light)
		light.global_position = light_global_pos
		var tween = get_tree().create_tween()
		tween.tween_property(light, "energy", 0.0, 2.0).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(light.queue_free)

	# 폭발 씬 인스턴스 생성
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = self.global_position
		get_parent().add_child(explosion)
		
		# 폭발 반경 설정 (모든 폭발 인스턴스에 적용)
		if explosion.has_method("set_radius"):
			explosion.set_radius(explosion_radius)
	
	queue_free()

# 플레이어가 현재 스테이지를 알려주기 위해 호출하는 함수
func set_current_stage(stage_name: String):
	self.current_stage = stage_name

# 폭발 반경을 설정하는 함수
func set_explosion_radius(radius: float):
	self.explosion_radius = radius

# 플레이어 스크립트에서 총알 크기를 조절하기 위해 호출하는 함수
func set_projectile_scale(new_scale: Vector2):
	var sprite = $Sprite2D
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale
		
func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false
