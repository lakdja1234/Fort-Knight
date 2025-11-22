extends RigidBody2D

# --- 폭발 관련 변수 ---
const ExplosionScene = preload("res://스테이지2/explosion.tscn")
@export var damage: int = 15
@export var explosion_radius: float = 150.0

# --- 미사일 능력치 ---
@export var speed: float = 600.0
@export var homing_speed: float = 1000.0
# 궤도 수정을 시작할 거리 (픽셀 단위, 인스펙터에서 조절 가능)
@export var homing_activation_range: float = 800.0 

var player: Node2D = null
# 방향 꺾기를 한 번만 하도록 체크하는 변수
var homing_turn_done: bool = false

# --- 시각/물리 노드 참조 추가 ---
@onready var sprite: Sprite2D = $Sprite2D # 미사일 이미지 노드 (경로 확인!)
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # 충돌 모양 노드 (경로 확인!)

var shooter = null
var explosion_created = false # NEW FLAG

func set_shooter(new_shooter: Node):
	shooter = new_shooter

func set_damage(amount: int):
	self.damage = amount



func _ready():
	add_to_group("bullets")
	# 물리 설정: 중력의 영향을 받도록 함
	gravity_scale = 1.0
	player = get_tree().get_first_node_in_group("player")
	
	body_entered.connect(_on_body_entered)
	
	# --- 노드 경로가 올바른지 확인 ---
	if not is_instance_valid(sprite):
		printerr("유도 미사일 오류: Sprite2D 노드를 찾을 수 없습니다! ($Sprite2D 경로 확인)")
	if not is_instance_valid(collision_shape):
		printerr("유도 미사일 오류: CollisionShape2D 노드를 찾을 수 없습니다! ($CollisionShape2D 경로 확인)")


func _physics_process(_delta):
	# ✅ 4. 방향 꺾기 로직
	# 아직 방향을 꺾지 않았고, 플레이어가 유효한지 확인
	if not homing_turn_done and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		# 거리가 설정한 범위 안으로 들어왔다면
		if distance <= homing_activation_range:
			homing_turn_done = true # ⬅️ 플래그를 true로 바꿔서 다시는 실행 안 되게 함
			
			# ✅ 중력을 끄고, 그 순간의 플레이어 위치로 방향을 "즉시" 꺾음
			gravity_scale = 0.0 # 중력 끄기
			var target_angle = (player.global_position - global_position).normalized().angle()
			rotation = target_angle # lerp_angle 대신 즉시 회전
			# print("유도 미사일: 1회 방향 꺾기 실행!")
	
	# --- 상태에 따른 비행 로직 ---
	if homing_turn_done:
		# --- 방향 꺾기 이후 (중력 꺼짐) ---
		# 꺾인 방향(rotation)으로 'speed'의 힘을 받아 직진
		linear_velocity = Vector2.RIGHT.rotated(rotation) * homing_speed
	else:
		# --- 방향 꺾기 이전 (중력 켜짐) ---
		# 포물선 비행 방향(linear_velocity)에 맞춰 스프라이트 회전
		rotation = linear_velocity.angle()
		

func _on_body_entered(body: Node):
	if body == shooter:
		return
	
	if explosion_created: return
	
	explosion_created = true # Set flag to true to prevent multiple calls
	# Disconnect the signal immediately to prevent further calls
	body_entered.disconnect(_on_body_entered) # NEW LINE

	call_deferred("create_explosion")
	
	# Aggressively prevent further collisions and queue free
	set_deferred("monitoring", false) # Disable collision monitoring immediately
	set_deferred("collision_mask", 0) # Remove from all collision checks
	call_deferred("queue_free") # Queue for free immediately




func create_explosion():
	# 1. 폭발 씬 인스턴스 생성
	var explosion = ExplosionScene.instantiate()

	# 2. 부모 노드(월드)에 폭발 씬 추가
	get_tree().root.add_child(explosion)

	# 3. 폭발 위치 설정
	explosion.global_position = self.global_position

	# --- 화면 흔들림 호출 ---
	var camera = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(15, 0.3) # 강도 15, 지속시간 0.3초

	# 폭발 씬에 반경 값 전달 (새 함수 호출)
	if explosion.has_method("set_radius"):
		explosion.set_radius(explosion_radius)

	# 폭발 씬에 데미지 값 전달
	explosion.damage = damage

	# 5. 포탄 자신은 소멸 (MOVED TO _on_body_entered)
	# call_deferred("queue_free")


# --- 외부에서 크기를 설정하는 함수 추가 ---
func set_projectile_scale(new_scale: Vector2):
	# 시각적 크기 조절
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	
	# 물리적 충돌 크기 조절 (매우 중요!)
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale
