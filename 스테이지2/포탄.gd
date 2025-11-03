extends RigidBody2D

# 인스펙터에서 데미지 양을 설정할 변수 export
@export var damage: int = 10 # 기본 데미지 10
# 폭발 반경 변수 추가 (인스펙터에서 조절 가능)
@export var explosion_radius: float = 300.0
# 폭발 씬을 미리 로드
const ExplosionScene = preload("res://스테이지2/explosion.tscn")
# WarningIndicator 씬 로드
const WarningScene = preload("res://스테이지2/warning_indicator.tscn")

# 시각적/물리적 노드 참조 추가
@onready var sprite: Sprite2D = $Sprite2D # 포탄 이미지 노드 (경로 확인!)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # 충돌 모양 노드 (경로 확인!)

# ✅ 1. 변수 이름을 'owner'에서 'shooter'로 변경
var shooter = null

# ✅ 2. 함수 이름을 'set_owner'에서 'set_shooter'로 변경
func set_shooter(new_shooter: Node):
	shooter = new_shooter

func _ready():
	# 이 노드를 "projectiles" 그룹에 추가합니다.
	# 다른 곳에서 충돌 검사 시 식별하는 데 도움이 됩니다.
	add_to_group("projectiles")

	# body_entered 시그널을 연결하여 충돌을 처리합니다.
	body_entered.connect(_on_body_entered)

	# 아무것도 맞히지 않고 너무 멀리 날아갈 경우
	# 발사체를 자동으로 파괴하는 타이머를 설정합니다.
	var despawn_timer = get_tree().create_timer(5.0) # 5초 후 자동 소멸
	despawn_timer.timeout.connect(queue_free)
	
# ---  _physics_process 함수 추가 ---
# 이 함수는 물리 엔진이 매 프레임마다 호출합니다.
func _physics_process(_delta):
	# linear_velocity(현재 이동 방향)의 각도를 계산하여
	# 노드 자체의 회전(rotation) 값에 적용합니다.
	rotation = linear_velocity.angle()
	
# 외부에서 크기를 설정하는 함수 추가
# new_scale은 Vector2(1.0, 1.0)이 기본 크기, Vector2(2.0, 2.0)은 2배 크기
func set_projectile_scale(new_scale: Vector2):
	# 시각적 크기 조절
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	
	# 물리적 충돌 크기 조절 (매우 중요!)
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale

func _on_body_entered(body: Node):
	
	# --- ✅ 3. 수정된 충돌 로직 ---
	
	# 1. '방어벽'인지 확인
	if body.is_in_group("wall"):
		# 1a. 발사 주체가 'player' 그룹일 때만 데미지
		if shooter != null and shooter.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(1) # HP 1 감소
		else:
			# (보스 포탄이므로 데미지 없음)
			print("보스 포탄이 방어벽에 부딪힘 (데미지 없음)")

	# 2. '보스 온열장치'인지 확인
	elif body.is_in_group("heaters"):
		if body.has_method("take_damage"):
			body.take_damage(damage) # 데미지 줌
		
	# 3. '맵 온열장치'인지 확인
	elif body.is_in_group("map_heaters"):
		if body.has_method("turn_on"):
			body.turn_on() # 켬

	# 4. '플레이어'인지 확인
	elif body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage) # 데미지 줌
	
	# 5. (기타) '보스'인지 확인
	elif body.is_in_group("boss"):
		if body.has_method("take_damage"):
			body.take_damage(damage) # 데미지 줌
			
		
	create_explosion()
	# queue_free()는 create_explosion 함수 내부에서 처리

## 폭발 생성 함수 (body_entered 내부에서 호출)
func create_explosion():
	# 1. 폭발 씬 인스턴스 생성
	var explosion = ExplosionScene.instantiate()

	# 2. 부모 노드(월드)에 폭발 씬 추가
	get_tree().root.add_child(explosion)

	# 3. 폭발 위치 설정
	explosion.global_position = self.global_position

	# 폭발 씬에 반경 값 전달 (새 함수 호출)
	if explosion.has_method("set_radius"):
		explosion.set_radius(explosion_radius)

	# 5. 포탄 자신은 소멸
	queue_free()

# ⚠️ 경고 생성 함수 (이 함수를 보스 스크립트 등이 호출하게 변경)
func create_warning(target_pos: Vector2):
	var warning = WarningScene.instantiate()
	get_tree().root.add_child(warning)
	warning.global_position = target_pos

	# 경고 씬에 반경 값 전달
	if warning.has_method("set_radius"):
		warning.set_radius(explosion_radius)

	return warning # 필요하다면 생성된 경고 노드 반환
