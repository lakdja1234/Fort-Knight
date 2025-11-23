extends StaticBody2D

# 1. 공격 패턴 ENUM
enum AttackPattern { 
	BASIC,    # 박격포 공격으로 사용
	BIG_SHOT, 
	BURST, 
	CLUSTER 
}

# 2. 발사할 씬 (외부에서 설정)
@export var basic_bullet_scene: PackedScene # [중요] 박격포용 "포탄.tscn"을 여기에 연결
@export var warning_scene: PackedScene    # [중요] 박격포용 "warning_indicator.tscn"을 여기에 연결
@export var big_bullet_scene: PackedScene # "큰 포탄"용
@export var cluster_bullet_scene: PackedScene # "분열탄"용
@export var burst_bullet_scene: PackedScene # "3연발"용

# 3. 박격포(기본) 공격 설정
const PROJECTILE_SPEED = 600.0
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 300.0

# 4. 노드 참조
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_position: Marker2D = $MuzzlePosition # [중요] 이름 통일
@onready var attack_timer: Timer = $AttackTimer
@onready var burst_timer: Timer = $BurstTimer

# 5. 보스 상태 변수
var player_target: Node2D = null 
var burst_count: int = 0

# 6. 공격 순서 (배열)
var attack_sequence = [
	AttackPattern.BASIC, # 박격포
	AttackPattern.BURST,
	AttackPattern.BASIC, # 박격포
	AttackPattern.BIG_SHOT,
	AttackPattern.BASIC, # 박격포
	AttackPattern.BURST,
	AttackPattern.BASIC, # 박격포
	AttackPattern.CLUSTER
]
var sequence_index = 0


# 7. 초기화 함수
func _ready():
	player_target = get_tree().get_first_node_in_group("player") # "Player" -> "player"
	
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	burst_timer.timeout.connect(_on_burst_timer_timeout)
	
	attack_timer.start()


# 9. 공격 타이머 종료 시 (공격 '관리자')
func _on_attack_timer_timeout():
	if player_target == null:
		player_target = get_tree().get_first_node_in_group("player") 
		if player_target == null:
			return # 플레이어가 없으면 대기
	animation_player.play("attack")
			
	# 3연발 중이 아닐 때만 다음 공격
	if burst_count == 0:
		var current_pattern = attack_sequence[sequence_index]
		sequence_index = (sequence_index + 1) % attack_sequence.size()
		
		execute_attack(current_pattern)
		
		attack_timer.start()

# 10. 공격 실행 (패턴 분기)
func execute_attack(pattern: AttackPattern):
	animation_player.play("attack") # 공통 공격 애니메이션
	
	match pattern:
		AttackPattern.BASIC:
			# [✅ 핵심] 기본 공격 시 '박격포' 함수 호출
			_execute_mortar_attack()
			
		AttackPattern.BIG_SHOT:
			spawn_bullet(big_bullet_scene) # 직사 화기
			
		AttackPattern.BURST:
			burst_count = 3 
			_on_burst_timer_timeout() 
			burst_timer.start()
			
			
		AttackPattern.CLUSTER:
			spawn_bullet(cluster_bullet_scene) # 직사 화기

# 11. 포탄 생성 (공통 함수) - BIG_SHOT, BURST, CLUSTER용
func spawn_bullet(bullet_scene: PackedScene):
	if bullet_scene == null:
		print("ERROR: ", bullet_scene, " 씬이 할당되지 않았습니다.")
		return
		
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = muzzle_position.global_position
	bullet.rotation = muzzle_position.global_rotation # 포구 방향으로 발사

# 12. 3연발 타이머 함수
func _on_burst_timer_timeout():
	if burst_count > 0:
		burst_count -= 1
		spawn_bullet(burst_bullet_scene)
		animation_player.play("attack")
		
		if burst_count == 0:
			burst_timer.stop()
	else:
		burst_timer.stop()

# ---
# ✅ 박격포 공격 (BASIC) 로직
# ---

# 13. [BASIC] 박격포 공격 '실행자' (경고 생성)
func _execute_mortar_attack():
	if player_target == null:
		return

	var current_attack_radius : float = EXPLOSION_RADIUS

	# 1. 플레이어 거리 및 오차 계산
	var distance_to_player = global_position.distance_to(player_target.global_position)
	var player_size = 100
	var max_error = player_size * 2
	var error_margin = clamp(inverse_lerp(200.0, 1000.0, distance_to_player), 0.0, 1.0) * max_error

	# 2. 초기 목표 X 좌표 계산
	var target_x_position = player_target.global_position.x + randf_range(-error_margin, error_margin)

	# 3. 실제 땅 Y 좌표 찾기 (Raycast)
	var space_state = get_world_2d().direct_space_state
	var ray_start = Vector2(target_x_position, -2000)
	var ray_end = Vector2(target_x_position, 2000)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	
	query.collision_mask = 1 # [중요] 지형(땅)의 물리 레이어 번호
	
	var result = space_state.intersect_ray(query)

	var final_target_position: Vector2
	if result:
		final_target_position = result.position
	else:
		final_target_position = player_target.global_position + Vector2(randf_range(-error_margin, error_margin), 0)

	# 4. 경고 표시 생성
	if warning_scene == null:
		printerr("ERROR: WarningScene이 인스펙터에 할당되지 않았습니다!")
		return
	var warning = warning_scene.instantiate()
	get_tree().root.add_child(warning)

	# 5. 경고 표시 Y축 위치 조정
	var visual_node = warning.get_node_or_null("Sprite2D") # warning 씬 내부의 스프라이트
	var warning_height = 0.0
	if visual_node:
		if visual_node is Sprite2D and visual_node.texture:
			warning_height = visual_node.texture.get_height() * visual_node.scale.y
		elif visual_node is ColorRect:
			warning_height = visual_node.size.y * visual_node.scale.y
	
	var adjusted_warning_position = final_target_position - Vector2(0, warning_height / 7.0)
	warning.global_position = adjusted_warning_position

	# 6. 경고 표시 크기 설정
	if warning.has_method("set_radius"):
		warning.set_radius(current_attack_radius)

	# 7. 경고 시간 후에 실제 발사 함수 호출
	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(final_target_position, current_attack_radius))
	

# 14. [BASIC] 실제 포탄 발사 함수 (포물선)
func _fire_projectile(fire_target_position: Vector2, radius: float):
	if player_target == null: return
	if basic_bullet_scene == null:
		printerr("ERROR: Basic Bullet Scene(포탄.tscn)이 인스펙터에 할당되지 않았습니다!")
		return

	var projectile = basic_bullet_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	projectile.set_collision_layer_value(4, true)
	projectile.set_collision_mask_value(1, true)
	projectile.global_position = muzzle_position.global_position # 포구에서 발사

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	var initial_velocity = calculate_parabolic_velocity(muzzle_position.global_position,
													  fire_target_position,
													  PROJECTILE_SPEED,
													  gravity)

	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)


# 15. [BASIC] 포물선 궤적 계산 함수
func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	var delta_y = -delta.y # 수학 좌표계로

	if abs(delta_x) < 0.1: # 수직 발사
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		printerr("경고: 최소 속력 계산 불가!")
		var fallback_angle = deg_to_rad(45.0) 
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed)

	var actual_launch_speed = max(desired_speed, min_launch_speed)
	var actual_speed_sq = actual_launch_speed * actual_launch_speed

	var gx = gravity * delta_x
	
	# [✅ 오타 수정됨]
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)
	
	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed 
	var vel_y_godot = -vel_y_math # Godot 좌표계로

	return Vector2(vel_x, vel_y_godot)
