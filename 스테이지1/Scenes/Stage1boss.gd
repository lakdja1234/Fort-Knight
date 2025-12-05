extends CharacterBody2D

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
const PROJECTILE_SPEED = 600
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 80.0

# 4. 노드 참조
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_position: Marker2D = $MuzzlePosition # [중요] 이름 통일
@onready var attack_timer: Timer = $AttackTimer
@onready var burst_timer: Timer = $BurstTimer

# 5. 보스 상태 변수
var player_target: Node2D = null 
var burst_count: int = 0
var hp: int = 1000 # <-- [✅ 이 줄을 추가하세요] (1000은 원하는 체력)

# --- ✅ 5-1. 제자리 복귀 변수 추가 ---
var initial_x: float # 보스의 기준 X좌표
const RETURN_STRENGTH = 8.0     # 복귀 강도 (이 값을 조절해 '부드러움'을 조절)
#const RETURN_ACCELERATION = 500.0 # 복귀 가속도 (높을수록 빨리 복귀)
const MAX_RETURN_SPEED = 200.0  # 최대 복귀 속도
# --- ✅ ---

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
	
	initial_x = global_position.x # <-- [✅ 이 줄을 추가]
	
	# 8. 물리 업데이트 (중력 적용)
func _physics_process(delta):
	# 1. 중력 적용 (Y축)
	if not is_on_floor(): # 공중에 떠있을 때만
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

	# ---
	# ✅ 2. 부드러운 제자리 복귀 로직 (Proportional Control)
	# ---
	# 현재 위치와 기준 위치의 차이 계산
	var difference = initial_x - global_position.x 

	# 목표 속도를 '차이'에 비례하도록 설정
	var target_x_velocity = difference * RETURN_STRENGTH 

	# (선택 사항) 복귀 속도가 너무 빠르지 않게 상한선 설정
	target_x_velocity = clamp(target_x_velocity, -MAX_RETURN_SPEED, MAX_RETURN_SPEED)

	# 현재 속도를 목표 속도로 '부드럽게' 변경 (핵심!)
	# lerp(from, to, weight) -> from에서 to로 weight만큼 부드럽게 이동
	velocity.x = lerp(velocity.x, target_x_velocity, delta * RETURN_STRENGTH)
	# --- ✅ ---

	# 3. move_and_slide() 호출 (필수!)
	move_and_slide()


# 9. 공격 타이머 종료 시 (공격 '관리자')
func _on_attack_timer_timeout():
	if player_target == null:
		player_target = get_tree().get_first_node_in_group("player") 
		if player_target == null:
			return # 플레이어가 없으면 대기
	
			
	# 3연발 중이 아닐 때만 다음 공격
	if burst_count == 0:
		var current_pattern = attack_sequence[sequence_index]
		sequence_index = (sequence_index + 1) % attack_sequence.size()
		
		execute_attack(current_pattern)
		
		attack_timer.start()

# 10. 공격 실행 (패턴 분기)
func execute_attack(pattern: AttackPattern):
	match pattern:
		AttackPattern.BASIC:
			_execute_mortar_attack(basic_bullet_scene) 
			
		AttackPattern.BIG_SHOT:
			_execute_mortar_attack(big_bullet_scene)
			
		AttackPattern.BURST:
			burst_count = 3 
			_on_burst_timer_timeout() 
			burst_timer.start()
			
		AttackPattern.CLUSTER:
			_execute_cluster_attack()

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
		_execute_mortar_attack(basic_bullet_scene)
		if burst_count == 0:
			burst_timer.stop()
	else:
		burst_timer.stop()

# ---
# ✅ CLUSTER ATTACK LOGIC
# ---
func _execute_cluster_attack():
	player_target = get_tree().get_first_node_in_group("player")
	if player_target == null:
		return

	var central_target_x = player_target.global_position.x
	var spread = 30.0 # Horizontal distance between sub-munition impacts

	var target_positions = []

	# Calculate three target positions and create warnings
	for i in range(-1, 2): # For -1, 0, 1
		var target_x = central_target_x + (i * spread)
		
		# Raycast to find the ground position for each target
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(Vector2(target_x, -2000), Vector2(target_x, 2000))
		query.collision_mask = 1 # World layer
		var result = space_state.intersect_ray(query)
		
		var final_target_pos: Vector2
		if result:
			final_target_pos = result.position
		else:
			# Fallback if no ground is found
			final_target_pos = Vector2(target_x, player_target.global_position.y - 8)
		
		target_positions.append(final_target_pos)
		
		# Create a warning indicator for each target position
		if warning_scene:
			var warning = warning_scene.instantiate()
			get_tree().root.add_child(warning)
			
			if warning.has_method("set_radius"):
				warning.set_radius(EXPLOSION_RADIUS)

			var visual_node = warning.get_node_or_null("Sprite2D")
			var warning_height = 0.0
			if visual_node:
				if visual_node is Sprite2D and visual_node.texture:
					warning_height = visual_node.texture.get_height() * visual_node.scale.y
				elif visual_node is ColorRect:
					warning_height = visual_node.size.y * visual_node.scale.y
			
			var adjusted_warning_position = final_target_pos - Vector2(0, warning_height / 2.0)
			warning.global_position = adjusted_warning_position

	# Fire the main cluster shell towards the central target
	var central_target_pos = target_positions[1]
	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	# Pass the individual target positions to the fire function
	fire_timer.timeout.connect(_fire_projectile.bind(central_target_pos, EXPLOSION_RADIUS, cluster_bullet_scene, target_positions))


# ---
# ✅ 박격포 공격 (BASIC) 로직
# ---
func _execute_mortar_attack(bullet_scene_to_fire: PackedScene): 
	player_target = get_tree().get_first_node_in_group("player") # (안전을 위해 새로고침)
	if player_target == null:
		return

	var current_attack_radius: float

	if bullet_scene_to_fire == big_bullet_scene:
		current_attack_radius = 160.0 
	else:
		current_attack_radius = EXPLOSION_RADIUS
 
	var distance_to_player = global_position.distance_to(player_target.global_position)
	var player_size = 100
	var max_error = player_size * 2
	var error_margin = clamp(inverse_lerp(200.0, 1000.0, distance_to_player), 0.0, 1.0) * max_error

	var target_x_position = player_target.global_position.x + randf_range(-error_margin, error_margin)

	var space_state = get_world_2d().direct_space_state
	var ray_start = Vector2(target_x_position, -2000)
	var ray_end = Vector2(target_x_position, 2000)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)

	var final_target_position: Vector2
	if result:
		final_target_position = result.position
	else:
		final_target_position = Vector2(target_x_position, player_target.global_position.y - 8)

	var warning = warning_scene.instantiate()
	get_tree().root.add_child(warning)

	if warning.has_method("set_radius"):
		warning.set_radius(current_attack_radius)
		
	var visual_node = warning.get_node("Sprite2D")
	var warning_height = 0.0
	if visual_node:
		if visual_node is Sprite2D and visual_node.texture:
			warning_height = visual_node.texture.get_height() * visual_node.scale.y
		elif visual_node is ColorRect:
			warning_height = visual_node.size.y * visual_node.scale.y
 
	var adjusted_warning_position = final_target_position - Vector2(0, warning_height / 2.0)
	if bullet_scene_to_fire == big_bullet_scene:
		adjusted_warning_position.y += 16 # Adjust downwards by 16 pixels
	warning.global_position = adjusted_warning_position

	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(final_target_position, current_attack_radius, bullet_scene_to_fire))

#14 [BASIC] 실제 포탄 발사 함
func _fire_projectile(fire_target_position: Vector2, radius: float, bullet_scene_to_fire: PackedScene, sub_targets: Array = []):
	if player_target == null: return
	
	if bullet_scene_to_fire == null: 
		printerr("ERROR: 발사할 Bullet Scene이 할당되지 않았습니다!")
		return

	animation_player.play("attack")

	var projectile = bullet_scene_to_fire.instantiate() 
	get_tree().root.add_child(projectile)
	
	# Pass target positions to the cluster shell if they exist
	if bullet_scene_to_fire == cluster_bullet_scene and not sub_targets.is_empty():
		projectile.target_positions = sub_targets

	# Set the collision properties directly to ensure the correct state
	projectile.collision_layer = 8 # Layer 4 for enemy bullets
	projectile.collision_mask = 3  # Detects Layer 1 (Ground) + Layer 2 (Player)

	projectile.global_position = muzzle_position.global_position

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	var initial_velocity = calculate_parabolic_velocity(muzzle_position.global_position,
													  fire_target_position,
													  PROJECTILE_SPEED,
													  gravity)

	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)


# 포물선 궤적을 위한 초기 속도 계산 함수 (항상 목표 도달 보장)
func calculate_parabolic_velocity(launch_pos: Vector2, target_pos: Vector2, desired_speed: float, gravity: float) -> Vector2:
	var delta = target_pos - launch_pos
	var delta_x = delta.x
	var delta_y = -delta.y

	if abs(delta_x) < 0.1:
		var vertical_speed = -desired_speed if delta_y > 0 else desired_speed
		return Vector2(0, vertical_speed)

	var min_speed_sq = gravity * (delta_y + sqrt(delta_x * delta_x + delta_y * delta_y))
	
	var min_launch_speed = 0.0
	if min_speed_sq >= 0:
		min_launch_speed = sqrt(min_speed_sq)
	else:
		var fallback_angle = deg_to_rad(45.0)
		return Vector2(cos(fallback_angle) * desired_speed, -sin(fallback_angle) * desired_speed)

	var actual_launch_speed = max(desired_speed, min_launch_speed)
	var actual_speed_sq = actual_launch_speed * actual_launch_speed

	var gx = gravity * delta_x
	var term_under_sqrt_calc = actual_speed_sq * actual_speed_sq - gravity * (gravity * delta_x * delta_x + 2 * delta_y * actual_speed_sq)
	if term_under_sqrt_calc < 0:
		term_under_sqrt_calc = 0
	var sqrt_term = sqrt(term_under_sqrt_calc)

	var launch_angle_rad = atan2(actual_speed_sq + sqrt_term, gx)

	var vel_x = cos(launch_angle_rad) * actual_launch_speed
	var vel_y_math = sin(launch_angle_rad) * actual_launch_speed
	var vel_y_godot = -vel_y_math

	var initial_velocity = Vector2(vel_x, vel_y_godot)
	return initial_velocity

func take_damage(amount: int):
	# 1. 체력 감소
	hp -= amount
	print("보스 피격! 남은 HP: ", hp)

	# 2. 피격 플래시 (Blink) 효과
	var tween = create_tween()
	
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	# 3. 체력이 0 이하면 사망 처리
	if hp <= 0:
		queue_free() # 보스 사망
