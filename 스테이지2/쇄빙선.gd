extends CharacterBody2D

signal health_updated(current_hp, max_hp)

var max_hp = 1000
var boss_hp = max_hp
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") # ✅ 중력 값 저장

@onready var overheat_timer = $OverheatDamageTimer
var total_heat_sinks = 0
var heat_sinks_destroyed = 0

# --- 1. 발사체 정보 통합 ---
const ProjectileScene = preload("res://스테이지2/포탄.tscn")
const WarningScene = preload("res://스테이지2/warning_indicator.tscn")
const HomingMissileScene = preload("res://스테이지2/homing_missile.tscn")
const IceWallScene = preload("res://스테이지2/iceWall.tscn")

# 기본 공격 설정
const BASIC_ATTACK_DAMAGE = 10
const BASIC_EXPLOSION_RADIUS = 300.0
const BASIC_PROJECTILE_SCALE = Vector2(3.0, 3.0)
const BASIC_WARNING_DURATION = 1.5

# 유도 미사일 설정
const HOMING_MISSILE_DAMAGE = 15
const HOMING_EXPLOSION_RADIUS = 75.0
const HOMING_PROJECTILE_SCALE = Vector2(2.5, 2.5)

# 포물선 공격 높이 설정
const ATTACK_APEX_HEIGHT = 300.0 # 발사 지점으로부터 포물선 최고점까지의 높이 (픽셀)

# 얼음벽 설정
const WALL_LAYER_MASK = 32 # 6번 레이어(wall)의 비트마스크 값 (2^(6-1))
const WALL_CHARGE_SPEED = 400.0
var is_charging_for_wall: bool = false
var wall_charge_direction: float = -1.0 # 왼쪽
var player: CharacterBody2D = null
var original_position: Vector2
var is_returning: bool = false

@onready var muzzle = $Muzzle
@onready var muzzle2 = $Muzzle2
@onready var homing_muzzle = $HomingMuzzle
@onready var attack_timer = $AttackTimer
@onready var homing_missile_timer = $HomingMissileTimer
@onready var sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
var second_attack_timer: Timer



func _ready():
	original_position = global_position
	player = get_tree().get_first_node_in_group("player")
	overheat_timer.timeout.connect(_on_overheat_timer_timeout)
	var heaters = get_tree().get_nodes_in_group("heaters")
	total_heat_sinks = heaters.size()
	if total_heat_sinks == 0:
		pass # printerr("경고: 'heaters' 그룹에 온열장치가 없습니다!")
	for heater in heaters:
		if heater.has_signal("spawn_wall_requested"):
			heater.spawn_wall_requested.connect(_on_spawn_wall_requested)
		else:
			pass # printerr("오류:", heater.name, "에 spawn_wall_requested 시그널이 없습니다.")	
	# print("보스 준비 완료. 총 온열장치 개수:", total_heat_sinks)

	# --- 온열장치와의 물리 충돌 방지 로직 ---
	# 'heaters' 그룹에 있는 노드(온열장치)를 찾습니다.
	var heaters_to_ignore = get_tree().get_nodes_in_group("heaters")
	if not heaters_to_ignore.is_empty():
		# 첫 번째 온열장치의 collision layer를 가져옵니다.
		var heater_layer = heaters_to_ignore[0].get_collision_layer()
		
		# 현재 보스의 collision mask에서 온열장치의 layer를 제외합니다.
		# (비트 연산: AND와 NOT을 사용하여 특정 비트를 끕니다)
		set_collision_mask(get_collision_mask() & ~heater_layer)
		# print("보스: 온열장치와의 물리 충돌을 비활성화했습니다.")
		
	# 유도 미사일은 상시 발사
	homing_missile_timer.start()

	# 기본 공격 타이머 연결 (Muzzle 1 사용)
	attack_timer.timeout.connect(_on_attack_timer_timeout.bind(muzzle))

	# 두 번째 공격 타이머 생성 및 설정 (Muzzle 2 사용)
	second_attack_timer = Timer.new()
	second_attack_timer.name = "SecondAttackTimer"
	second_attack_timer.wait_time = 5.0
	second_attack_timer.timeout.connect(_on_attack_timer_timeout.bind(muzzle2))
	add_child(second_attack_timer)
		
	emit_signal("health_updated", boss_hp, max_hp)

	

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
						
						# print("보스: '앞쪽 지형'과 충돌! 돌진 중지 및 방어벽 생성.")
						is_charging_for_wall = false
						velocity.x = 0
						
						var wall_spawn_pos = collision.get_position() + normal * 2.0
						spawn_ice_wall(wall_spawn_pos)
						is_returning = true # 돌아가기 상태 활성화
						
						break
	elif is_returning:
		var direction_to_origin = (original_position - global_position).normalized()
		velocity.x = direction_to_origin.x * WALL_CHARGE_SPEED

		move_and_slide()

		# 충분히 가까워지면 정지
		if global_position.distance_to(original_position) < 10:
			is_returning = false
			velocity.x = 0
			global_position = original_position # 정확한 위치로 보정
			# print("보스: 원래 위치로 복귀 완료.")
	else:
		velocity.x = move_toward(velocity.x, 0, delta)
		if velocity.length() > 0.1:
			move_and_slide()
		

# 기본 공격 타이머 (어떤 포구에서 쏠지 인자로 받음)
func _on_attack_timer_timeout(muzzle_node: Node2D):
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
		muzzle_node,
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
	
	# --- 온열장치를 레이캐스트에서 제외 ---
	var heaters_to_exclude_nodes = get_tree().get_nodes_in_group("map_heaters")
	var heaters_to_exclude_rids = []
	for heater in heaters_to_exclude_nodes:
		heaters_to_exclude_rids.append(heater.get_rid())

	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 33 # 수정: 기본 지형(1)과 얼음 벽(32)을 모두 감지
	query.exclude = heaters_to_exclude_rids # 제외할 RID 목록 설정
	# --- 제외 로직 끝 ---

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
	explosion_radius: float, 
	projectile_scale: Vector2
):
	if player == null:
		return
		
	var fire_target_pos = target_pos
	var dynamic_apex_height = ATTACK_APEX_HEIGHT 

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(muzzle_node.global_position, target_pos)
	query.collision_mask = WALL_LAYER_MASK
	
	var result = space_state.intersect_ray(query)

	if result:
		# print("보스: 방어벽이 궤적을 막고 있음! 궤도를 높여서 발사합니다.")
		fire_target_pos = target_pos + Vector2(0, -500)
		dynamic_apex_height += 800 # 목표가 높아진 만큼, 최고점도 높여줌

	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = muzzle_node.global_position
	
	if projectile.has_method("set_shooter"):
		projectile.set_shooter(self)

	var initial_velocity = _calculate_parabolic_velocity_local(
								muzzle_node.global_position,
								fire_target_pos,
								gravity,
								dynamic_apex_height # 고정값 대신 동적 최고 높이 전달
							)
	
	projectile.linear_velocity = initial_velocity

	if projectile.has_method("set_explosion_radius"):
		projectile.set_explosion_radius(explosion_radius)
		
	if projectile.has_method("set_projectile_scale"):
		projectile.set_projectile_scale(projectile_scale)
	else:
		pass # printerr("오류: Projectile 씬에 set_projectile_scale 함수가 없습니다!")
	
	if projectile_scene == ProjectileScene:
		if projectile.has_method("set_damage"):
			projectile.set_damage(BASIC_ATTACK_DAMAGE)
		else:
			projectile.damage = BASIC_ATTACK_DAMAGE
	elif projectile_scene == HomingMissileScene:
		if projectile.has_method("set_damage"):
			projectile.set_damage(HOMING_MISSILE_DAMAGE)
		else:
			projectile.damage = HOMING_MISSILE_DAMAGE


# '고정된 최고 높이' 포물선 발사를 위한 속도 계산 함수
func _calculate_parabolic_velocity_local(start_pos: Vector2, end_pos: Vector2, p_gravity: float, apex_height: float) -> Vector2:
	var diff = end_pos - start_pos
	var dist_x = diff.x
	var dist_y = diff.y

	if abs(dist_x) < 1.0:
		dist_x = 1.0 # 0으로 나누기 방지

	# 1. 최고점에 도달하기 위한 초기 Y 속도 계산
	# v_y^2 = 2 * g * h  =>  v_y = sqrt(2 * g * h)
	var initial_vy = -sqrt(2 * p_gravity * apex_height)

	# 2. 최고점까지 올라가는 데 걸리는 시간 계산
	# v = v0 + at  =>  0 = initial_vy + g*t  =>  t = -initial_vy / g
	var time_to_apex = -initial_vy / p_gravity

	# 3. 최고점에서 목표 Y좌표까지 떨어지는 데 걸리는 시간 계산
	# d = 0.5 * g * t^2  =>  t = sqrt(2d/g)
	var fall_distance = apex_height + dist_y
	if fall_distance < 0:
		# 목표가 최고점보다 위에 있어 도달할 수 없는 경우
		# printerr("목표에 도달할 수 없습니다. (목표가 최고점보다 높음)")
		return Vector2(0, initial_vy) # 일단 위로 쏘기

	var time_to_fall = sqrt(2 * fall_distance / p_gravity)

	# 4. 총 비행 시간
	var total_time = time_to_apex + time_to_fall

	# 5. 총 비행 시간 동안 수평 거리를 이동하기 위한 X 속도 계산
	# d = v*t  =>  v = d/t
	var initial_vx = dist_x / total_time
	
	return Vector2(initial_vx, initial_vy)





# --- 온열장치가 파괴될 때마다 호출될 함수 ---
func _on_heat_sink_destroyed():
	heat_sinks_destroyed += 1
	# print("보스: 온열장치 파괴 감지! (%d / %d)" % [heat_sinks_destroyed, total_heat_sinks])

	# 첫 번째 온열장치가 파괴되면 추가 기본 공격 패턴 활성화
	if heat_sinks_destroyed == 1:
		# print("보스: 첫 온열장치 파괴! 5초마다 기본 공격을 추가로 발사합니다.")
		second_attack_timer.start()
	
	# 모든 온열장치가 파괴되었는지 확인
	if heat_sinks_destroyed >= total_heat_sinks:
		start_overheating()

# 과열(행동 불능) 상태 시작 함수
func start_overheating():
	# print("!!! 보스 과열! 행동 불능 상태 돌입 !!!")
	sprite.play("freeze")
	
	# (선택 사항) 모든 공격 타이머 중지
	attack_timer.stop()
	homing_missile_timer.stop()
	if is_instance_valid(second_attack_timer):
		second_attack_timer.stop()
	
	# 초당 100 데미지 타이머 시작
	overheat_timer.start()

# 1초마다 호출되어 HP를 100씩 감소시키는 함수
func _on_overheat_timer_timeout():
	# print("과열 데미지! -100 HP")
	take_damage(100) #

# 보스 자신의 데미지 처리 함수
func take_damage(amount: int):
	# 이미 죽음 절차가 시작되었다면 데미지를 더 받지 않음
	if boss_hp <= 0:
		return
		
	boss_hp -= amount
	# print("보스 HP:", boss_hp)
	
	emit_signal("health_updated", boss_hp, max_hp)
	
	if boss_hp <= 0 and not is_queued_for_deletion():
		overheat_timer.stop() # 데미지 타이머 중지
		_start_sinking() # 가라앉기 시작


# 보스가 아래로 가라앉으며 사라지는 함수
func _start_sinking():
	# print("보스 처치! 가라앉기 시작합니다.")
	
	# 1. 모든 공격 동작 정지
	attack_timer.stop()
	homing_missile_timer.stop()
	if is_instance_valid(second_attack_timer):
		second_attack_timer.stop()

	# 2. 물리 충돌 비활성화 (가라앉는 동안 다른 것에 부딪히지 않도록)
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true

	# 3. Tween (애니메이션) 생성
	var tween = create_tween()
	# 3초에 걸쳐 현재 위치에서 Y축으로 400픽셀만큼 아래로 이동
	tween.tween_property(self, "global_position:y", global_position.y + 400, 3.0)\
		 .set_ease(Tween.EASE_IN) # 서서히 가속하며 가라앉는 느낌
	# 동시에 15도 기울어지도록 회전
	tween.parallel().tween_property(self, "rotation_degrees", 15, 3.0)\
		 .set_ease(Tween.EASE_IN_OUT)

	# 4. 애니메이션이 끝나면 보상 화면 표시
	tween.tween_callback(_show_reward_screen)

func _show_reward_screen():
	# 1. Create a CanvasLayer to render the UI independent of camera zoom.
	var ui_layer = CanvasLayer.new()
	
	# 2. Load and instance the reward scene.
	var reward_scene = load("res://파츠/stage2reward.tscn").instantiate()
	
	# 3. Add the reward scene to the CanvasLayer.
	ui_layer.add_child(reward_scene)
	
	# 4. Add the CanvasLayer to the scene tree, making it visible.
	get_tree().root.add_child(ui_layer)
	
	# Let the reward scene's root Control fill the entire CanvasLayer.
	if reward_scene is Control:
		reward_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	# The boss can now be removed.
	queue_free()



# 온열장치가 50% HP일 때 호출될 함수 (수정)
func _on_spawn_wall_requested():
	# 이미 돌진 중이거나 과열(사망) 상태면 무시
	if is_charging_for_wall or boss_hp <= 0:
		return
		
	# print("보스: 온열장치 50% HP 감지, 방어벽 생성을 위해 돌진 시작!")
	is_charging_for_wall = true
	
	# --- ✅ 2. 플레이어 방향 확인 및 돌진 방향/스프라이트 설정 ---
	if player.global_position.x < global_position.x:
		wall_charge_direction = -1.0 # 플레이어가 왼쪽에 있음
	else:
		wall_charge_direction = 1.0  # 플레이어가 오른쪽에 있음
	
	# --- ✅ 설정 끝 ---
	

# 방어벽 생성 함수 (spawn_position 인자 받도록 수정)
func spawn_ice_wall(spawn_position: Vector2):
	# print("보스: 방어벽 생성 시도 (충돌 지점):", spawn_position)
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
		pass # printerr("경고: IceWall의 높이를 계산할 수 없습니다. 'AnimatedSprite2D' 노드와 'build' 애니메이션을 확인하세요.")
		 # 예비로 50픽셀 높이 사용
		wall_height = 50.0 
	
	# --- ✅ 2. Y축 위치 보정 ---
	var adjusted_spawn_position = spawn_position - Vector2(0, wall_height / 2.0)
	
	get_parent().add_child(wall)
	wall.global_position = adjusted_spawn_position
	# print("보스: 방어벽 최종 생성 위치:", adjusted_spawn_position)


func _on_toggle_homing_button_toggled(_toggled_on: bool) -> void:
	if is_instance_valid(homing_missile_timer):
			if homing_missile_timer.is_stopped():
				homing_missile_timer.start()
				# print("--- (디버그 버튼) 유도 미사일 타이머 [시작됨] ---")
			else:
				homing_missile_timer.stop()
				# print("--- (디버그 버튼) 유도 미사일 타이머 [정지됨] ---")


func _on_spawn_wall_button_pressed() -> void:
	_on_spawn_wall_requested()
