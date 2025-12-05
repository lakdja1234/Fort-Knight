extends RigidBody2D

# --- 폭발 관련 변수 ---
const ExplosionScene = preload("res://스테이지2/explosion.tscn")
@export var damage: int = 15
@export var explosion_radius: float = 150.0

# --- 미사일 능력치 ---
@export var speed: float = 600.0 # This speed is used by the player's fire_bullet function
@export var homing_speed: float = 1000.0
# 궤도 수정을 시작할 거리 (픽셀 단위, 인스펙터에서 조절 가능)
@export var homing_activation_range: float = 800.0 

var target: Node2D = null
# 방향 꺾기를 한 번만 하도록 체크하는 변수
var homing_turn_done: bool = false

# --- 시각/물리 노드 참조 추가 ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var shooter = null
var explosion_created = false

func set_shooter(new_shooter: Node):
	shooter = new_shooter

func set_damage(amount: int):
	self.damage = amount

func _ready():
	add_to_group("bullets")
	# 물리 설정: 중력의 영향을 받도록 함
	gravity_scale = 1.0
	
	body_entered.connect(_on_body_entered)
	
	if not is_instance_valid(sprite):
		printerr("유도 미사일 오류: Sprite2D 노드를 찾을 수 없습니다! ($Sprite2D 경로 확인)")
	if not is_instance_valid(collision_shape):
		printerr("유도 미사일 오류: CollisionShape2D 노드를 찾을 수 없습니다! ($CollisionShape2D 경로 확인)")

func _physics_process(_delta):
	# 1. 목표물이 없으면 우선순위에 따라 탐색
	if not is_instance_valid(target):
		find_target_with_priority()

	# 2. 유도 로직 (방향 꺾기)
	# 아직 방향을 꺾지 않았고, 타겟이 유효한지 확인
	if not homing_turn_done and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		
		# 거리가 설정한 범위 안으로 들어왔다면
		if distance <= homing_activation_range:
			homing_turn_done = true # 플래그를 true로 바꿔서 다시는 실행 안 되게 함
			
			# 중력을 끄고, 그 순간의 타겟 위치로 방향을 "즉시" 꺾음
			gravity_scale = 0.0 # 중력 끄기
			var target_angle = (target.global_position - global_position).normalized().angle()
			rotation = target_angle
	
	# 3. 상태에 따른 비행 로직
	if homing_turn_done:
		# 방향 꺾기 이후 (중력 꺼짐): 꺾인 방향으로 직진
		linear_velocity = Vector2.RIGHT.rotated(rotation) * homing_speed
	else:
		# 방향 꺾기 이전 (중력 켜짐): 포물선 비행 방향에 맞춰 스프라이트 회전
		rotation = linear_velocity.angle()

func find_target_with_priority():
	# This missile belongs to the boss, so it only targets the player.
	target = get_tree().get_first_node_in_group("player")

		
func _on_body_entered(body: Node):
	if body == shooter:
		return
	
	if explosion_created: return
	
	explosion_created = true
	body_entered.disconnect(_on_body_entered)

	call_deferred("create_explosion")
	
	set_deferred("monitoring", false)
	set_deferred("collision_mask", 0)
	call_deferred("queue_free")

func create_explosion():
	var explosion = ExplosionScene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = self.global_position

	var camera = get_tree().get_first_node_in_group("camera")
	if is_instance_valid(camera) and camera.has_method("shake"):
		camera.shake(15, 0.3)

	if explosion.has_method("set_radius"):
		explosion.set_radius(explosion_radius)

	explosion.damage = damage

func set_projectile_scale(new_scale: Vector2):
	if is_instance_valid(sprite):
		sprite.scale = new_scale
	if is_instance_valid(collision_shape):
		collision_shape.scale = new_scale
