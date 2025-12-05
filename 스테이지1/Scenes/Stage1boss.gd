extends CharacterBody2D

signal health_updated(current_hp, max_hp)
signal boss_died

# 1. 공격 패턴 ENUM
enum AttackPattern { 
	BASIC,
	BIG_SHOT, 
	BURST, 
	CLUSTER 
}

# 2. 발사할 씬 (외부에서 설정)
@export var basic_bullet_scene: PackedScene
@export var warning_scene: PackedScene
@export var big_bullet_scene: PackedScene
@export var cluster_bullet_scene: PackedScene
@export var burst_bullet_scene: PackedScene

# 3. 공격 설정
const PROJECTILE_SPEED = 600
const WARNING_DURATION = 1.5
const EXPLOSION_RADIUS = 80.0

# 4. 노드 참조
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_position: Marker2D = $MuzzlePosition
@onready var attack_timer: Timer = $AttackTimer
@onready var burst_timer: Timer = $BurstTimer

# 5. 보스 상태 변수
var player_target: Node2D = null 
var burst_count: int = 0
var max_hp: int = 300 # 보스 최대 체력
var hp: int = 300 # 현재 체력

var initial_x: float
const RETURN_STRENGTH = 8.0
const MAX_RETURN_SPEED = 200.0
var lights_disabled = false

func set_lights_disabled(disabled: bool):
	lights_disabled = disabled

# 6. 공격 순서 관련 변수 제거
# var attack_sequence = [...]
# var sequence_index = 0

func _ready():
	add_to_group("boss")
	player_target = get_tree().get_first_node_in_group("player")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	burst_timer.timeout.connect(_on_burst_timer_timeout)
	attack_timer.start()
	initial_x = global_position.x
	# 체력바 초기화
	emit_signal("health_updated", hp, max_hp)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	var difference = initial_x - global_position.x 
	var target_x_velocity = difference * RETURN_STRENGTH 
	target_x_velocity = clamp(target_x_velocity, -MAX_RETURN_SPEED, MAX_RETURN_SPEED)
	velocity.x = lerp(velocity.x, target_x_velocity, delta * RETURN_STRENGTH)
	move_and_slide()

# --- 수정된 공격 타이머 로직 ---
func _on_attack_timer_timeout():
	if player_target == null:
		player_target = get_tree().get_first_node_in_group("player") 
		if player_target == null:
			# 플레이어가 없으면 공격 중지
			return
			
	if burst_count > 0:
		# 3연발 공격 중에는 새로운 공격을 시작하지 않음
		return

	# 1. 체력 비율 계산
	var hp_ratio = float(hp) / float(max_hp)
	
	# 2. 가능한 공격 목록 생성
	var possible_attacks = []
	if hp_ratio > 0.66:
		# 페이즈 1: 기본 공격과 큰 포탄
		possible_attacks = [AttackPattern.BASIC, AttackPattern.BIG_SHOT]
	elif hp_ratio > 0.33:
		# 페이즈 2: 분열탄 추가
		possible_attacks = [AttackPattern.BASIC, AttackPattern.BIG_SHOT, AttackPattern.CLUSTER]
	else:
		# 페이즈 3: 3연발 추가
		possible_attacks = [AttackPattern.BASIC, AttackPattern.BIG_SHOT, AttackPattern.CLUSTER, AttackPattern.BURST]
	
	# 3. 공격 랜덤 선택 및 실행
	if not possible_attacks.is_empty():
		var chosen_pattern = possible_attacks.pick_random()
		execute_attack(chosen_pattern)
		
	attack_timer.start() # 다음 공격 타이머 시작

func execute_attack(pattern: AttackPattern):
	match pattern:
		AttackPattern.BASIC:
			_execute_mortar_attack(basic_bullet_scene) 
		AttackPattern.BIG_SHOT:
			_execute_mortar_attack(big_bullet_scene)
		AttackPattern.BURST:
			burst_count = 3 
			_on_burst_timer_timeout() # 즉시 1회 발사
			burst_timer.start() # 이후 타이머에 맞춰 2회 발사
		AttackPattern.CLUSTER:
			_execute_cluster_attack()

func _on_burst_timer_timeout():
	if burst_count > 0:
		burst_count -= 1
		# 3연발 공격은 항상 기본 총알 사용
		_execute_mortar_attack(basic_bullet_scene)
		if burst_count == 0:
			burst_timer.stop()
	else:
		burst_timer.stop()

func _execute_cluster_attack():
	player_target = get_tree().get_first_node_in_group("player")
	if player_target == null:
		return

	var central_target_x = player_target.global_position.x
	var spread = 30.0

	var target_positions = []

	for i in range(-1, 2):
		var target_x = central_target_x + (i * spread)
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(Vector2(target_x, -2000), Vector2(target_x, 2000))
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		
		var final_target_pos: Vector2
		if result:
			final_target_pos = result.position
		else:
			final_target_pos = Vector2(target_x, player_target.global_position.y - 8)
		
		target_positions.append(final_target_pos)
		
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

	var central_target_pos = target_positions[1]
	var fire_timer = get_tree().create_timer(WARNING_DURATION)
	fire_timer.timeout.connect(_fire_projectile.bind(central_target_pos, EXPLOSION_RADIUS, cluster_bullet_scene, target_positions))

func _execute_mortar_attack(bullet_scene_to_fire: PackedScene): 
	player_target = get_tree().get_first_node_in_group("player") # (안전을 위해 새로고침)
	if player_target == null:
		return

	var current_attack_radius: float

	if bullet_scene_to_fire == big_bullet_scene:
		current_attack_radius = 107.0 
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

func _fire_projectile(fire_target_position: Vector2, radius: float, bullet_scene_to_fire: PackedScene, sub_targets: Array = []):
	if player_target == null: return
	if bullet_scene_to_fire == null: 
		printerr("ERROR: 발사할 Bullet Scene이 할당되지 않았습니다!")
		return

	animation_player.play("attack")
	var projectile = bullet_scene_to_fire.instantiate() 

	# Disable light if commanded by GameManager
	if lights_disabled:
		var light = projectile.get_node_or_null("PointLight2D")
		if light:
			light.visible = false
	
	# --- 모든 속성을 씬에 추가하기 전에 설정 (중요) ---
	projectile.owner_node = self
	projectile.global_position = muzzle_position.global_position

	if bullet_scene_to_fire == cluster_bullet_scene and not sub_targets.is_empty():
		projectile.target_positions = sub_targets

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	var initial_velocity = calculate_parabolic_velocity(muzzle_position.global_position,
													  fire_target_position,
													  PROJECTILE_SPEED,
													  gravity)
	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(radius)
	
	# --- 모든 설정이 끝난 후 씬에 추가 ---
	get_tree().root.add_child(projectile)


func take_damage(amount: int):
	hp -= amount
	emit_signal("health_updated", hp, max_hp)
	print("보스 피격! 남은 HP: ", hp)

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	if hp <= 0:
		emit_signal("boss_died")
		queue_free()

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
