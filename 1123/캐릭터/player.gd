extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const ACCELERATION = 1000.0  # 가속도 (값이 높을수록 최대 속도에 빨리 도달)
const FRICTION_NORMAL = 1200.0 # 일반 땅의 마찰력 (값이 높을수록 빨리 멈춤)
const FRICTION_ICE = 0.03    # 얼음 땅의 마찰력 (lerp용 값)

var is_on_ice = false
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
		
	# ✅ 바닥 확인 로직 수정 (원형 충돌 기준)
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

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	else:
		if is_on_ice:
			velocity.x = lerp(velocity.x, 0.0, FRICTION_ICE)
		else:	
			velocity.x = move_toward(velocity.x, 0.0, FRICTION_NORMAL * delta)

	move_and_slide()
