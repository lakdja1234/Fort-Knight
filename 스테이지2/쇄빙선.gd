extends CharacterBody2D

var boss_hp: int = 1000 
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") # ✅ 중력 값 저장

@onready var overheat_timer = $OverheatDamageTimer
var total_heat_sinks = 0
var heat_sinks_destroyed = 0

# --- 1. 발사체 정보 통합 ---
const ProjectileScene = preload("res://스테이지2/포탄.tscn")
const WarningScene = preload("res://스테이지2/warning_indicator.tscn")
const HomingMissileScene = preload("res://homing_missile.tscn")
const IceWallScene = preload("res://IceWall.tscn")

# 기본 공격 설정
const BASIC_ATTACK_SPEED = 600.0
const BASIC_EXPLOSION_RADIUS = 300.0
const BASIC_PROJECTILE_SCALE = Vector2(2.5, 2.5) # 하드코딩된 값 사용
const BASIC_WARNING_DURATION = 1.5

# 유도 미사일 설정 (HomingMissile.gd의 @export var speed와 일치시킬 필요 있음)
const HOMING_MISSILE_SPEED = 600.0 
const HOMING_EXPLOSION_RADIUS = 75.0
const HOMING_PROJECTILE_SCALE = Vector2(2.5, 2.5) # 하드코딩된 값 사용

# 얼음벽 설정
const WALL_LAYER_MASK = 4 # 3번 레이어(wall)의 비트마스크 값 (2^(3-1))
const WALL_CHARGE_SPEED = 400.0
var is_charging_for_wall: bool = false
var wall_charge_direction: float = -1.0 # 왼쪽
var player: CharacterBody2D = null

@onready var muzzle = $Muzzle
@onready var homing_muzzle = $HomingMuzzle
@onready var attack_timer = $AttackTimer
@onready var homing_missile_timer = $HomingMissileTimer


func _ready():
	# (기존 _ready 함수 내용과 동일 - 수정 불필요)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	player = get_tree().get_first_node_in_group("player")
	homing_missile_timer.timeout.connect(_on_homing_missile_timer_timeout)
	overheat_timer.timeout.connect(_on_overheat_timer_timeout)
	var heaters = get_tree().get_nodes_in_group("heaters")
	total_heat_sinks = heaters.size()
	if total_heat_sinks == 0:
		printerr("경고: 'heaters' 그룹에 온열장치가 없습니다!")
	for heater in heaters:
		if heater.has_signal("heat_sink_destroyed"):
			heater.heat_sink_destroyed.connect(_on_heat_sink_destroyed)
		else:
			printerr("오류:", heater.name, "에 heat_sink_destroyed 시그널이 없습니다.")
		if heater.has_signal("spawn_wall_requested"):
			heater.spawn_wall_requested.connect(_on_spawn_wall_requested)
		else:
			printerr("오류:", heater.name, "에 spawn_wall_requested 시그널이 없습니다.")	
	print("보스 준비 완료. 총 온열장치 개수:", total_heat_sinks)
	

func _physics_process(delta):
	# (기존 _physics_process 함수 내용과 동일 - 수정 불필요)
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if is_charging_for_wall:
		velocity.x = wall_charge_direction * WALL_CHARGE_SPEED
		
		move_and_slide()
		
		var collision_count = get_slide_collision_count()
		if collision_count > 0:
			for i in range(collision_count):
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				var normal = collision.get_normal()
				
				# --- ✅ 2. (수정) 'wall_charge_direction' 변수로 충돌 방향 확인 ---
				if collider is TileMapLayer and abs(normal.x) > 0.5:
					# (오른쪽(1.0)으로 돌진 중일 때, 벽의 법선은 왼쪽(-1.0)이어야 함)
					if (wall_charge_direction > 0 and normal.x < -0.5) or \
					   (wall_charge_direction < 0 and normal.x > 0.5):
						
						print("보스: '앞쪽 지형'과 충돌! 돌진 중지 및 방어벽 생성.")
						is_charging_for_wall = false
						velocity.x = 0
						
						var wall_spawn_pos = collision.get_position() + normal * 2.0
						spawn_ice_wall(wall_spawn_pos)
						
						break
	else:
		velocity.x = move_toward(velocity.x, 0, 1000 * delta)
		move_and_slide()
		

# 기본 공격 타이머
func _on_attack_timer_timeout():
	if player == null:
		return
	
	# 1. 목표 지점 계산
	var target_pos = _calculate_target_position()
	
	# 2. 경고 표시
	var _warning = _spawn_warning_indicator(target_pos, BASIC_EXPLOSION_RADIUS)

	# 3. 경고 시간 후 '범용 발사 함수' 호출
	var fire_timer = get_tree().create_timer(BASIC_WARNING_DURATION)
	fire_timer.timeout.connect(_fire_generic_projectile.bind(
		target_pos,
		ProjectileScene,
		muzzle,
		BASIC_ATTACK_SPEED,
		BASIC_EXPLOSION_RADIUS,
		BASIC_PROJECTILE_SCALE
	))
	

# 유도 미사일 타이머
func _on_homing_missile_timer_timeout():
	if player == null:
		return
	
	# 1. 목표 지점 계산
	var target_pos = _calculate_target_position()
	
	# 2. 경고 없이 '범용 발사 함수' 즉시 호출
	_fire_generic_projectile(
		target_pos,
		HomingMissileScene,
		homing_muzzle,
		HOMING_MISSILE_SPEED,
		HOMING_EXPLOSION_RADIUS,
		HOMING_PROJECTILE_SCALE
	)


# 목표 지점 계산 함수
func _calculate_target_position() -> Vector2:
	# 1. 플레이어 거리 및 오차 계산
	var distance_to_player = global_position.distance_to(player.global_position)
	var player_size = 100
	var max_error = player_size * 2
	var error_margin = clamp(inverse_lerp(200.0, 1000.0, distance_to_player), 0.0, 1.0) * max_error
	var base_target_position = player.global_position + Vector2(randf_range(-error_margin, error_margin), 0)

	# 2. 실제 땅 Y 좌표 찾기 (Raycast)
	var space_state = get_world_2d().direct_space_state
	var ray_start = Vector2(base_target_position.x, -2000)
	var ray_end = Vector2(base_target_position.x, 2000)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)

	if result:
		return result.position # 레이캐스트 성공
	else:
		return base_target_position # 실패 시 플레이어 Y좌표 사용


# 파라미터 이름을 "spawn_pos"로 변경
func _spawn_warning_indicator(spawn_pos: Vector2, radius: float) -> Node:
	var warning = WarningScene.instantiate()
	get_tree().root.add_child(warning)

	# Y축 위치 조정 (기존 코드)
	var visual_node = warning.get_node("Sprite2D")
	var warning_height = 0.0
	if visual_node:
		if visual_node is Sprite2D and visual_node.texture:
			warning_height = visual_node.texture.get_height() * visual_node.scale.y
		elif visual_node is ColorRect:
			warning_height = visual_node.size.y * visual_node.scale.y
			
	# "position" 대신 "spawn_pos" 사용
	var adjusted_warning_position = spawn_pos - Vector2(0, warning_height / 7.0)
	warning.global_position = adjusted_warning_position

	# 크기 설정
	if warning.has_method("set_radius"):
		warning.set_radius(radius)
	
	return warning


# --- '범용 발사 함수' ---
func _fire_generic_projectile(
	target_pos: Vector2, 
	projectile_scene: PackedScene, 
	muzzle_node: Node2D, 
	launch_speed: float, 
	explosion_radius: float, 
	projectile_scale: Vector2
):
	if player == null:
		return
		
	# --- ✅ 1. 발사 전 궤도 확인 ---
	var fire_target_pos = target_pos # 기본 목표 지점
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.create(muzzle_node.global_position, target_pos)
	query.collision_mask = WALL_LAYER_MASK # (스크립트 상단에 WALL_LAYER_MASK가 정의되어 있어야 함)
	
	var result = space_state.intersect_ray(query)

	if result:
		print("보스: 방어벽이 궤적을 막고 있음! 궤도를 높여서 발사합니다.")
		fire_target_pos = target_pos + Vector2(0, -1000) # 500픽셀 더 높이 조준
	# --- ✅ 궤도 확인 끝 ---

	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = muzzle_node.global_position
	
	# --- ✅ 2. (수정) 발사 주체 설정 ---
	if projectile.has_method("set_shooter"):
		projectile.set_shooter(self) # 'self'는 보스 자신을 의미

	# --- ✅ 3. (수정) 'gravity' 변수 사용 ---
	#    (스크립트 상단에 'var gravity = ...'가 선언되어 있어야 함)
	var initial_velocity = GlobalPhysics.calculate_parabolic_velocity(
								muzzle_node.global_position,
								fire_target_pos,
								launch_speed,
								gravity # ⬅️ 지역 변수가 아닌 멤버 변수 사용
							)
	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(explosion_radius)
		
	if projectile.has_method("set_projectile_scale"):
		projectile.set_projectile_scale(projectile_scale)
	else:
		printerr("오류: Projectile 씬에 set_projectile_scale 함수가 없습니다!")


# --- 온열장치가 파괴될 때마다 호출될 함수 ---
func _on_heat_sink_destroyed():
	heat_sinks_destroyed += 1
	print("보스: 온열장치 파괴 감지! (%d / %d)" % [heat_sinks_destroyed, total_heat_sinks])
	
	# 모든 온열장치가 파괴되었는지 확인
	if heat_sinks_destroyed >= total_heat_sinks:
		start_overheating()

# 과열(행동 불능) 상태 시작 함수
func start_overheating():
	print("!!! 보스 과열! 행동 불능 상태 돌입 !!!")
	
	# (선택 사항) 모든 공격 타이머 중지
	attack_timer.stop()
	if has_node("HomingMissileTimer"):
		$HomingMissileTimer.stop()
	
	# 초당 100 데미지 타이머 시작
	overheat_timer.start()

# 1초마다 호출되어 HP를 100씩 감소시키는 함수
func _on_overheat_timer_timeout():
	print("과열 데미지! -100 HP")
	take_damage(100) #

# 보스 자신의 데미지 처리 함수
func take_damage(amount: int):
	boss_hp -= amount
	print("보스 HP:", boss_hp)
	
	if boss_hp <= 0 and not is_queued_for_deletion():
		print("보스 처치!")
		overheat_timer.stop() # 데미지 타이머 중지
		queue_free() # 보스 사망


# 온열장치가 50% HP일 때 호출될 함수 (수정)
func _on_spawn_wall_requested():
	# 이미 돌진 중이거나 과열(사망) 상태면 무시
	if is_charging_for_wall or boss_hp <= 0:
		return
		
	print("보스: 온열장치 50% HP 감지, 방어벽 생성을 위해 돌진 시작!")
	is_charging_for_wall = true
	
	# --- ✅ 2. 플레이어 방향 확인 및 돌진 방향/스프라이트 설정 ---
	if player.global_position.x < global_position.x:
		wall_charge_direction = -1.0 # 플레이어가 왼쪽에 있음
	else:
		wall_charge_direction = 1.0  # 플레이어가 오른쪽에 있음
	
	# 돌진 방향에 맞게 스프라이트 뒤집기 (Sprite2D 노드 경로 확인!)
	$AnimatedSprite2D.flip_h = (wall_charge_direction == 1.0)
	# --- ✅ 설정 끝 ---
	

# 방어벽 생성 함수 (spawn_position 인자 받도록 수정)
func spawn_ice_wall(spawn_position: Vector2):
	print("보스: 방어벽 생성 시도 (충돌 지점):", spawn_position)
	var wall = IceWallScene.instantiate()
	
	# --- ✅ 1. 방어벽의 높이 계산 (스프라이트 기준) ---
	var wall_height = 0.0
	
	# 'AnimatedSprite2D' 노드를 찾습니다. (스크린샷의 노드 이름 기준)
	var wall_sprite = wall.get_node_or_null("AnimatedSprite2D") 
	
	if is_instance_valid(wall_sprite) and wall_sprite.sprite_frames:
		# 'default' 애니메이션의 첫 번째 프레임 텍스처를 가져옵니다.
		# (또는 'idle' 등 기준이 되는 애니메이션 이름 사용)
		var frame_texture = wall_sprite.sprite_frames.get_frame_texture("build", 0)
		if frame_texture:
			# 텍스처의 실제 높이와 스케일을 곱하여 최종 높이 계산
			wall_height = frame_texture.get_height() * wall_sprite.scale.y
	
	if wall_height == 0.0:
		printerr("경고: IceWall의 높이를 계산할 수 없습니다. 'AnimatedSprite2D' 노드와 'build' 애니메이션을 확인하세요.")
		 # 예비로 50픽셀 높이 사용
		wall_height = 50.0 
	
	# --- ✅ 2. Y축 위치 보정 ---
	var adjusted_spawn_position = spawn_position - Vector2(0, wall_height / 2.0)
	
	get_parent().add_child(wall)
	wall.global_position = adjusted_spawn_position
	print("보스: 방어벽 최종 생성 위치:", adjusted_spawn_position)
