extends CharacterBody2D

const ProjectileScene = preload("res://포탄.tscn")
const WarningScene = preload("res://warning_indicator.tscn")

var player: CharacterBody2D = null
const PROJECTILE_SPEED = 600.0
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 300.0 # 기본 폭발 반경 (set_radius에 전달될 값)

@onready var muzzle = $Muzzle
@onready var attack_timer = $AttackTimer

func _ready():
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	player = get_tree().get_first_node_in_group("player")

# AttackTimer가 끝나면 호출될 함수
func _on_attack_timer_timeout():
	if player == null:
		return

	var current_attack_radius : float = EXPLOSION_RADIUS

	# 1. 플레이어 거리 및 오차 계산 (기존과 동일)
	# ... (distance_to_player, error_margin 계산) ...
	var distance_to_player = global_position.distance_to(player.global_position)
	var player_size = 100
	var max_error = player_size * 2
	var error_margin = clamp(inverse_lerp(200.0, 1000.0, distance_to_player), 0.0, 1.0) * max_error


	# 2. 초기 목표 X 좌표 계산 (플레이어 위치 + 랜덤 오차)
	var target_x_position = player.global_position.x + randf_range(-error_margin, error_margin)

	# --- ✅ 3. 실제 땅 Y 좌표 찾기 (Raycast) ---
	var space_state = get_world_2d().direct_space_state
	
	var ray_start = Vector2(target_x_position, -2000) # 화면 맨 위
	var ray_end = Vector2(target_x_position, 2000)   # 화면 맨 아래
	
	# 1. 쿼리 파라미터 생성 및 설정
	#    create() 함수에 시작점과 끝점을 전달합니다.
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)

	# 2. (중요) 충돌 마스크(Collision Mask) 설정
	#    레이저가 어떤 물리 레이어와 충돌할지 지정합니다.
	#    이 값을 설정하지 않으면 레이저가 모든 것을 뚫고 지나갈 수 있습니다.
	#    여기서는 1번 물리 레이어(지형)와만 충돌하도록 설정합니다.
	query.collision_mask = 1 # 예시: 1번 레이어 (지형)

	# (선택 사항) 특정 노드 제외하기
	# query.exclude = [self] # 보스 자신은 제외

	# 3. 레이저 발사 및 결과 받기
	var result = space_state.intersect_ray(query)

	var final_target_position: Vector2
	if result:
		# 4. 결과 사용
		final_target_position = result.position
		print("레이캐스트 성공! 실제 땅 위치:", final_target_position)
	else:
		# 5. 실패 처리 (기존 코드)
		final_target_position = player.global_position + Vector2(randf_range(-error_margin, error_margin), 0)
		print("레이캐스트 실패. 플레이어 위치 기준:", final_target_position)
	# --- ✅ 실제 땅 Y 좌표 찾기 끝 ---


	# 4. 경고 표시 생성
	var warning = WarningScene.instantiate()
	get_tree().root.add_child(warning)

	# --- ✅ 경고 표시 Y축 위치 조정 (최종) ---
	var visual_node = warning.get_node("Sprite2D") # 경로 확인!
	var warning_height = 0.0
	if visual_node:
		if visual_node is Sprite2D and visual_node.texture:
			warning_height = visual_node.texture.get_height() * visual_node.scale.y
		elif visual_node is ColorRect:
			warning_height = visual_node.size.y * visual_node.scale.y

	# 경고 표시의 '아랫변'이 '실제 땅 위치'에 닿도록 위치 조정
	var adjusted_warning_position = final_target_position - Vector2(0, warning_height / 7.0)
	
	warning.global_position = adjusted_warning_position
	print("경고 표시 최종 위치:", warning.global_position)
	# --- ✅ 경고 표시 Y축 위치 조정 끝 ---

	# 5. 경고 표시 크기 설정
	if warning.has_method("set_radius"):
		warning.set_radius(current_attack_radius)

	# 6. 경고 시간 후에 실제 발사 함수 호출
	#    .bind()에 '실제 땅 위치'를 전달
	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(final_target_position, current_attack_radius))
	

# 실제 포탄 발사 함수
func _fire_projectile(fire_target_position: Vector2, radius: float):
	if player == null:
		return

	print("포탄 발사 시도! 계산 목표:", fire_target_position)

	var projectile = ProjectileScene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = muzzle.global_position

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var initial_velocity = calculate_parabolic_velocity(muzzle.global_position,
													  fire_target_position,
													  PROJECTILE_SPEED,
													  gravity)

	projectile.linear_velocity = initial_velocity
	print("적용된 초기 속도:", initial_velocity) # <-- 발사 직전 속도 확인

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)


# 포물선 궤적을 위한 초기 속도 계산 함수 (항상 목표 도달 보장)
func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	# --- ✅ 1. 좌표계 통일 (수학 좌표계로 변경) ---
	var delta_y = -delta.y # Godot의 Y(아래가 +)를 수학의 Y(위가 +)로 뒤집음
	# --- ✅ 1. 좌표계 통일 끝 ---

	print("--- 각도 계산 시작 ---")
	print("발사 위치:", launch_pos, ", 목표 위치:", target_pos)
	print("delta_x:", delta_x, ", delta_y(수학):", delta_y)

	if abs(delta_x) < 0.1:
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	# 목표 지점에 도달하기 위한 최소 속력 제곱(v^2) 계산 (수학 기준 Y 사용)
	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		printerr("경고: 최소 속력 계산 불가!")
		var fallback_angle = deg_to_rad(45.0) # 수학 기준 45도
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed) # Y축만 Godot에 맞게 뒤집음

	var actual_launch_speed = max(desired_speed, min_launch_speed)
	var actual_speed_sq = actual_launch_speed * actual_launch_speed
	print("실제 발사 속력:", actual_launch_speed)

	var gx = gravity * delta_x
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	# --- ✅ 2. atan() 대신 atan2() 사용하여 명확한 각도 계산 ---
	# 높은 각도 계산 (Y, X 순서로 입력)
	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)
	print("계산된 각도 (rad):", launch_angle_rad, ", (deg):", rad_to_deg(launch_angle_rad))
	# --- ✅ 2. atan2()로 변경 끝 ---

	# --- ✅ 3. 최종 속도 벡터 생성 (cos/sin 직접 사용) ---
	# atan2가 올바른 각도를 반환하므로, cos/sin이 X, Y 부호를 자동으로 처리해 줌
	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed # 수학 기준 Y 속도

	# Godot 좌표계(Y축 아래가 +)에 맞게 수학 기준 Y 속도 부호 반전
	var vel_y_godot = -vel_y_math

	# 최종 속도 벡터 생성
	var initial_velocity = Vector2(vel_x, vel_y_godot)
	# --- ✅ 3. 최종 속도 벡터 생성 끝 ---

	print("최종 속도 벡터:", initial_velocity) # Y 부호가 음수(-)가 되어야 위로 쏨
	print("--- 각도 계산 끝 ---")
	return initial_velocity

func _physics_process(delta):
	pass
