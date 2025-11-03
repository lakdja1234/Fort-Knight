extends CharacterBody2D

# --- 속도 관련 상수 ---
const SPEED_ORIGINAL = 300.0
const ACCELERATION_NORMAL_ORIGINAL = 1000.0
const ACCELERATION_ICE_ORIGINAL = 500.0
const FRICTION_NORMAL = 1200.0
const FRICTION_ICE = 0.001 # ⬅️ (0.03에서 0.001로 수정하신 값 반영)

# --- 현재 적용될 값 변수 ---
var current_speed = SPEED_ORIGINAL
var current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
var current_accel_ice = ACCELERATION_ICE_ORIGINAL

var is_on_ice = false

# --- 냉동 게이지 변수 ---
var max_freeze_gauge: float = 100.0
var current_freeze_gauge: float = 0.0
var freeze_rate: float = 5.0  # 초당 차오르는 속도
var warm_rate: float = 20.0 # 초당 내려가는 속도
var is_warming_up: bool = false # 온열장치 범위 안에 있는지
var is_frozen: bool = false     # 게이지가 가득 찼는지

# TileMapLayer 노드를 참조할 변수
@onready var ice_map_layer: TileMapLayer = null
# 탱크의 CollisionShape2D 노드를 참조
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# "ground_tilemap" 그룹에서 TileMapLayer 찾기
	#    (씬 구조에 맞게 그룹 이름을 사용하거나, 경로를 직접 지정할 수 있음)
	ice_map_layer = get_tree().get_first_node_in_group("ground_tilemap")
	if ice_map_layer == null:
		printerr("플레이어: 'ground_tilemap' 그룹에서 TileMapLayer를 찾을 수 없습니다!")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# 바닥 확인 로직 수정 (원형 충돌 기준)
	if is_instance_valid(ice_map_layer) and ice_map_layer.has_method("is_tile_ice"):
		if is_instance_valid(collision_shape):
			# 1. 충돌 모양이 원형인지 확인
			if collision_shape.shape is CircleShape2D:
				# 2. 원형의 반지름(radius)을 가져옴
				var radius = collision_shape.shape.radius
				
				# 3. 바닥 좌표 계산 (탱크의 바닥보다 1픽셀 더 아래)
				var floor_check_position = global_position + Vector2(0, radius + 1)
				
				is_on_ice = ice_map_layer.is_tile_ice(floor_check_position)
				
				# (디버깅용) print("바닥 확인 좌표:", floor_check_position, " / 얼음?:", is_on_ice)
			else:
				# (예외 처리) 만약 원형이 아니면, 이전 사각형 로직 수행
				var half_height = collision_shape.shape.size.y / 2.0
				var floor_check_position = global_position + Vector2(0, half_height + 1)
				is_on_ice = ice_map_layer.is_tile_ice(floor_check_position)
		else:
			is_on_ice = false # collision_shape이 없으면 확인 불가
	else:
		is_on_ice = false # 맵이 없으면 미끄러지지 않음

	
	# --- 가속/감속 로직 ---
	var direction := Input.get_axis("ui_left", "ui_right")
	var target_velocity_x = direction * current_speed # 'current_speed' 변수 사용

	if is_on_ice:
		# --- 얼음 위일 때 ---
		if direction:
			# 'current_accel_ice' 변수 사용
			velocity.x = move_toward(velocity.x, target_velocity_x, current_accel_ice * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, FRICTION_ICE)
	else:
		# --- 일반 땅일 때 ---
		if direction:
			# 'current_accel_normal' 변수 사용
			velocity.x = move_toward(velocity.x, target_velocity_x, current_accel_normal * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION_NORMAL * delta)
			
	update_freeze_gauge(delta)
	move_and_slide()

# 냉동 게이지 계산 함수
func update_freeze_gauge(delta: float):
	var previous_gauge = current_freeze_gauge # 값 변경 확인용

	if is_warming_up:
		# 온열장치 범위 안: 게이지 감소
		current_freeze_gauge = max(current_freeze_gauge - warm_rate * delta, 0.0)
	else:
		current_freeze_gauge = min(current_freeze_gauge + freeze_rate * delta, max_freeze_gauge)

	# --- 게이지 값이 변경될 때만 print로 확인 ---
	if previous_gauge != current_freeze_gauge and fmod(current_freeze_gauge, 10.0) == 0.0:
		print("냉동 게이지:", current_freeze_gauge, "/", max_freeze_gauge)
	
	# 기동력 저하 디버프 적용
	if current_freeze_gauge >= max_freeze_gauge and not is_frozen:
		is_frozen = true
		apply_freeze_debuff(true) # 디버프 적용
	# 게이지가 0이 되었고, 얼어붙은 상태였다면 -> 해동!
	elif current_freeze_gauge == 0.0 and is_frozen:
		is_frozen = false
		apply_freeze_debuff(false) # 디버프 해제

# 디버프 적용/해제 함수 (print문 유지)
func apply_freeze_debuff(frozen: bool):
	if frozen:
		print("!!! 얼어붙음! 기동력 50% 저하 !!!")
		# 현재 값들을 원본의 50%로 설정
		current_speed = SPEED_ORIGINAL * 0.5
		current_accel_normal = ACCELERATION_NORMAL_ORIGINAL * 0.5
		current_accel_ice = ACCELERATION_ICE_ORIGINAL * 0.5
	else:
		print("!!! 해동됨! 기동력 100% 복구 !!!")
		# 현재 값들을 원본의 100%로 복구
		current_speed = SPEED_ORIGINAL
		current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
		current_accel_ice = ACCELERATION_ICE_ORIGINAL

# 온열장치가 호출할 함수들 (public)
func start_warming_up():
	is_warming_up = true

func stop_warming_up():
	is_warming_up = false
