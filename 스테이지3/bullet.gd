extends RigidBody2D

# --- 1. 모든 @export 변수 통합 ---
@export var damage: int = 10 # 기본 데미지
@export var explosion_radius: float = 300.0 # 폭발 반경
const ExplosionScene = preload("res://스테이지2/explosion.tscn") # 폭발 씬

# --- 2. 노드 참조 통합 ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# (bullet.gd에서 가져온 기능)
@onready var light: PointLight2D = $PointLight2D # 조명 노드 (씬에 추가해야 함)
@onready var collision_enable_timer: Timer = $CollisionEnableTimer # 충돌 활성화 타이머 (씬에 추가해야 함)

# --- 3. 상태 변수 통합 ---
var shooter = null # 발사 주체 (표준화)
var can_collide = false # (bullet.gd에서 가져온 기능)

func _ready():
	add_to_group("projectiles") # "bullets" 대신 "projectiles" 그룹 사용 (포탄.gd 기준)
	
	# (bullet.gd에서 가져온 기능)
	collision_shape.disabled = true # 1. 시작 시 충돌 비활성화
	collision_enable_timer.start()  # 2. 활성화 타이머 시작
	
	# (포탄.gd에서 가져온 기능)
	var despawn_timer = get_tree().create_timer(5.0) # 5초 후 자동 소멸
	despawn_timer.timeout.connect(queue_free)

# (bullet.gd에서 가져온 기능)
func _on_collision_enable_timer_timeout():
	can_collide = true
	collision_shape.disabled = false

func set_shooter(new_shooter: Node):
	shooter = new_shooter

func set_projectile_scale(new_scale: Vector2):
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale

func _physics_process(_delta):
	rotation = linear_velocity.angle()

func _on_screen_exited():
	queue_free() # (bullet.gd에서 가져온 유용한 기능)

# --- 4. _on_body_entered 로직 통합 ---
func _on_body_entered(body: Node):
	# (bullet.gd의 안전장치) 충돌이 활성화되기 전이거나, 자기 자신(shooter)과 부딪혔다면 무시
	if not can_collide or (shooter and body == shooter):
		return

	# (포탄.gd의 그룹 기반 충돌 로직)
	if body.is_in_group("wall"):
		if shooter != null and shooter.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(1)
		else:
			print("보스 포탄이 방어벽에 부딪힘 (데미지 없음)")
	elif body.is_in_group("heaters"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
	elif body.is_in_group("map_heaters"):
		if body.has_method("turn_on"):
			body.turn_on()
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
	elif body.is_in_group("boss"):
		pass # Damage will be handled by the explosion
	
	# (포탄.gd의 안전한 폭발 호출)
	call_deferred("create_explosion")

# --- 5. create_explosion 로직 통합 ---
func create_explosion():
	if is_queued_for_deletion():
		return

	remove_from_group("projectiles") # (bullet.gd에서 가져온 기능)

	# (bullet.gd의 조명 분리 로직)
	if light:
		var light_global_pos = light.global_position
		var main_scene = get_tree().root
		light.get_parent().remove_child(light) # 1. 포탄에서 조명 분리
		main_scene.add_child(light)            # 2. 월드에 조명 추가
		light.global_position = light_global_pos
		# 3. 조명 서서히 끄기
		var tween = get_tree().create_tween()
		tween.tween_property(light, "energy", 0.0, 2.0).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(light.queue_free)

	# (포탄.gd의 폭발 생성 로직)
	if ExplosionScene:
		var explosion = ExplosionScene.instantiate()
		get_tree().root.add_child(explosion)
		explosion.global_position = self.global_position
		if explosion.has_method("set_radius"):
			explosion.set_radius(explosion_radius)
	
	# (포탄.gd의 안전한 소멸)
	call_deferred("queue_free")
