# player.gd (MERGED)
extends CharacterBody2D

signal game_over
signal health_updated(current_hp)
signal freeze_gauge_changed(current_value, max_value)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 1. 변수 설정 (S3 Base)
@export var bullet_scene: PackedScene

@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint
@onready var progress_bar = $ChargeBar
@onready var cooldown_timer = $CooldownTimer

# --- 이동 변수 (S2 & S3 Merged) ---
const SPEED_ORIGINAL = 400.0
const ACCELERATION_NORMAL_ORIGINAL = 1000.0
const ACCELERATION_ICE_ORIGINAL = 500.0
const FRICTION_NORMAL = 1000.0 # Using S3's friction value
const FRICTION_ICE = 0.001

var current_speed = SPEED_ORIGINAL
var current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
var current_accel_ice = ACCELERATION_ICE_ORIGINAL

var is_on_ice = false # 이 변수는 얼음 위에서의 '미끄러짐' 물리 효과에 계속 사용됩니다.
var current_floor_type: String = "NORMAL" # 냉동 게이지 계산에 사용될 새로운 변수

# --- 조준 변수 (S3) ---
const AIM_SPEED = 2.0

# --- 통합 시스템 변수 (S3) ---
const MIN_FIRE_POWER = 500.0
const MAX_FIRE_POWER = 2000.0
const CHARGE_RATE = 1000.0
const COOLDOWN_DURATION = 3.0

# --- 색상 변수 (S3) ---
const CHARGE_COLOR = Color.YELLOW
const COOLDOWN_COLOR = Color.RED

var is_charging = false
var current_power = MIN_FIRE_POWER
var can_fire = true
var hp = 100

# --- 냉동 게이지 변수 (S2) ---
var max_freeze_gauge: float = 100.0
var current_freeze_gauge: float = 0.0
const FREEZE_RATE_ICE: float = 7.0 # 얼음 위에서 게이지 차는 속도
const FREEZE_RATE_MELTED: float = 2.0 # 녹은 얼음 위에서 게이지 차는 속도
var warm_rate: float = 20.0
var is_warming_up: bool = false
var is_frozen: bool = false

var _print_timer: float = 0.0
const PRINT_INTERVAL: float = 1.0

# --- 노드 참조 (S2 & S3 Merged) ---
@onready var ice_map_layer: TileMapLayer = null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # S2
@onready var background = get_node_or_null("/root/TitleMap/Background") # S3

var bullet_path_points = []
const BULLET_PATH_DURATION = 2.0


# _ready 함수 (Merged)
func _ready():
	add_to_group("player")
	
	# S3: ProgressBar 설정
	progress_bar.show_percentage = false 
	setup_bar_for_charging()
	
	# S2: TileMapLayer 찾기
	ice_map_layer = get_tree().get_first_node_in_group("ground_tilemap")
	if ice_map_layer == null:
		printerr("플레이어: 'ground_tilemap' 그룹에서 TileMapLayer를 찾을 수 없습니다! (얼음 물리 비활성화)")
		
	emit_signal("health_updated", hp)
	emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)


# ProgressBar 관련 함수들 (S3)
func setup_bar_for_charging():
	progress_bar.min_value = MIN_FIRE_POWER
	progress_bar.max_value = MAX_FIRE_POWER
	progress_bar.value = MIN_FIRE_POWER
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = CHARGE_COLOR
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")

func setup_bar_for_cooldown():
	progress_bar.min_value = 0.0
	progress_bar.max_value = COOLDOWN_DURATION
	progress_bar.value = COOLDOWN_DURATION
	var stylebox_original = progress_bar.get_theme_stylebox("foreground")
	if stylebox_original:
		var stylebox_copy = stylebox_original.duplicate()
		stylebox_copy.bg_color = COOLDOWN_COLOR
		progress_bar.add_theme_stylebox_override("foreground", stylebox_copy)
	else:
		print("경고: ChargeBar의 'Theme Overrides' > 'Styles' > 'Foreground'에 StyleBoxFlat이 설정되지 않았습니다.")



func _physics_process(delta):
	# --- S2: 중력 ---
	if not is_on_floor():
		velocity.y += gravity * delta

	# --- S2: 바닥 상태 확인 (물리 효과 및 냉동 게이지용) ---
	if is_instance_valid(ice_map_layer) and ice_map_layer.has_method("get_player_floor_type"):
		# 타일맵 스크립트에 플레이어 노드 자신을 넘겨 모든 계산을 위임
		current_floor_type = ice_map_layer.get_player_floor_type(self)
		is_on_ice = (current_floor_type == "ICE")
	else:
		current_floor_type = "NORMAL"
		is_on_ice = false

	# --- 냉동 게이지 업데이트 (매 프레임 호출) ---
	update_freeze_gauge(delta)

	# --- 냉동 게이지 1초마다 출력 ---
	_print_timer += delta
	if _print_timer >= PRINT_INTERVAL:
		print("냉동 게이지:", current_freeze_gauge, "/", max_freeze_gauge)
		_print_timer = 0.0

	# --- S2/S3: 이동 처리 (얼음 물리 적용) ---
	var direction = Input.get_axis("move_left", "move_right") # S3 입력 사용
	var target_velocity_x = direction * current_speed

	if is_on_ice:
		if direction:
			velocity.x = move_toward(velocity.x, target_velocity_x, current_accel_ice * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, FRICTION_ICE)
	else:
		if direction:
			velocity.x = move_toward(velocity.x, target_velocity_x, current_accel_normal * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION_NORMAL * delta)
	
	move_and_slide()

	# --- S3: 포신 각도 조절 ---
	var aim_direction = Input.get_axis("aim_up", "aim_down")
	cannon_pivot.rotation += aim_direction * AIM_SPEED * delta
	cannon_pivot.rotation = clamp(cannon_pivot.rotation, -PI, 0.0)
	
	# --- S3: 통합 발사/쿨다운 로직 ---
	if can_fire:
		if Input.is_action_just_pressed("fire"):
			is_charging = true
			current_power = MIN_FIRE_POWER
			progress_bar.value = current_power
		if is_charging and Input.is_action_pressed("fire"):
			current_power += CHARGE_RATE * delta
			current_power = min(current_power, MAX_FIRE_POWER)
			progress_bar.value = current_power
		if is_charging and Input.is_action_just_released("fire"):
			is_charging = false
			can_fire = false 
			fire_bullet(current_power)
			cooldown_timer.start()
			setup_bar_for_cooldown()
	else:
		progress_bar.value = cooldown_timer.time_left

	# --- S3: 쉐이더 업데이트 (조건부 실행) ---
	var game_manager = get_node_or_null("/root/TitleMap/GameManager")
	if is_instance_valid(background) and background.material and is_instance_valid(game_manager) and not game_manager.is_darkness_active:
		var light_positions = []
		light_positions.append(background.to_local(global_position))
		var bullets = get_tree().get_nodes_in_group("bullets")
		for bullet in bullets:
			bullet_path_points.append({"position": background.to_local(bullet.global_position), "timestamp": Time.get_ticks_msec()})
		var current_time = Time.get_ticks_msec()
		bullet_path_points = bullet_path_points.filter(func(point):
			return current_time - point.timestamp < BULLET_PATH_DURATION * 1000
		)
		bullet_path_points.sort_custom(func(a, b): return a.timestamp > b.timestamp)
		var max_points = 127
		var points_to_add = bullet_path_points.slice(0, min(bullet_path_points.size(), max_points))
		for point in points_to_add:
			light_positions.append(point.position)
		background.material.set_shader_parameter("light_positions", light_positions)
		background.material.set_shader_parameter("light_count", light_positions.size())


# 발사 함수 (S3)
func fire_bullet(power: float):
	if not bullet_scene:
		print("!!! 중요: Player 노드의 인스펙터 창에서 'Bullet Scene'을 연결해주세요! !!!")
		return
	var bullet = bullet_scene.instantiate()
	bullet.collision_layer = 3
	get_parent().add_child(bullet)

	# 스테이지 2와 3의 발사체 스크립트 호환을 위한 처리
	if bullet.has_method("set_shooter"):
		bullet.set_shooter(self) # Stage 2 방식
	else:
		bullet.owner_node = self # Stage 3 방식 (또는 기본)

	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power

# 쿨다운 타이머 함수 (S3)
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging()

# 데미지 및 충돌 함수 (S3)
func take_damage(amount):
	# 이미 사망했다면 더 이상 데미지를 받지 않음
	if hp <= 0:
		return

	hp -= amount
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	emit_signal("health_updated", hp)
	
	if hp <= 0:
		print("플레이어 사망, game_over 신호 발생 시도")
		emit_signal("game_over")
		# 플레이어를 숨기고 충돌을 비활성화하여 '사망' 처리
		hide()
		collision_shape.set_deferred("disabled", true)

func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10)
		if body.has_method("create_explosion"):
			body.call_deferred("create_explosion")
		else:
			body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)

# --- 냉동 게이지 함수 (S2) ---
func update_freeze_gauge(delta: float):
	# 얼음 맵이 아니면 게이지를 0으로 만들고 함수 종료
	if not is_instance_valid(ice_map_layer):
		current_freeze_gauge = 0
		return

	# 1순위: 온열장치 위에 있으면 무조건 게이지 감소
	if is_warming_up:
		current_freeze_gauge = max(current_freeze_gauge - warm_rate * delta, 0.0)
	# 2순위: 얼음 타일 위에서는 많이 증가
	elif current_floor_type == "ICE":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_ICE * delta, max_freeze_gauge)
	# 3순위: 녹은 타일 위에서는 조금 증가
	elif current_floor_type == "MELTED":
		current_freeze_gauge = min(current_freeze_gauge + FREEZE_RATE_MELTED * delta, max_freeze_gauge)
	
	emit_signal("freeze_gauge_changed", current_freeze_gauge, max_freeze_gauge)
	# 그 외의 경우(NORMAL 바닥)는 게이지 변경 없음


	
	if current_freeze_gauge >= max_freeze_gauge and not is_frozen:
		is_frozen = true
		apply_freeze_debuff(true)
	elif current_freeze_gauge == 0 and is_frozen: # 게이지가 0이 되어야만 해동
		is_frozen = false
		apply_freeze_debuff(false)

func apply_freeze_debuff(frozen: bool):
	if frozen:
		print("!!! 얼어붙음! 기동력 50% 저하 !!!")
		current_speed = SPEED_ORIGINAL * 0.5
		current_accel_normal = ACCELERATION_NORMAL_ORIGINAL * 0.5
		current_accel_ice = ACCELERATION_ICE_ORIGINAL * 0.5
	else:
		print("!!! 해동됨! 기동력 100% 복구 !!!")
		current_speed = SPEED_ORIGINAL
		current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
		current_accel_ice = ACCELERATION_ICE_ORIGINAL

func start_warming_up():
	is_warming_up = true

func stop_warming_up():
	is_warming_up = false
