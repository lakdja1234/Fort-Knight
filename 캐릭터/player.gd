# player.gd (MERGED)
extends CharacterBody2D

signal game_over

# 1. 변수 설정 (S3 Base)
@export var bullet_scene: PackedScene

@onready var cannon_pivot = $CannonPivot
@onready var fire_point = $CannonPivot/FirePoint
@onready var progress_bar = $ChargeBar
@onready var cooldown_timer = $CooldownTimer

# --- 이동 변수 (S2 & S3 Merged) ---
const SPEED_ORIGINAL = 300.0
const ACCELERATION_NORMAL_ORIGINAL = 1000.0
const ACCELERATION_ICE_ORIGINAL = 500.0
const FRICTION_NORMAL = 1000.0 # Using S3's friction value
const FRICTION_ICE = 0.001

var current_speed = SPEED_ORIGINAL
var current_accel_normal = ACCELERATION_NORMAL_ORIGINAL
var current_accel_ice = ACCELERATION_ICE_ORIGINAL

var is_on_ice = false

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
var freeze_rate: float = 5.0
var warm_rate: float = 20.0
var is_warming_up: bool = false
var is_frozen: bool = false

var _print_timer: float = 0.0
const PRINT_INTERVAL: float = 1.0

# --- 노드 참조 (S2 & S3 Merged) ---
@onready var ice_map_layer: TileMapLayer = null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # S2
@onready var background = get_node("/root/TitleMap/Background") # S3

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


# _physics_process (Merged)
func _physics_process(delta):
	# --- S2: 중력 ---
	if not is_on_floor():
		velocity.y += get_gravity() * delta

	# --- S2: 얼음 바닥 확인 (수정) ---
	if is_instance_valid(ice_map_layer) and ice_map_layer.has_method("get_player_floor_type"):
		var floor_type = ice_map_layer.get_player_floor_type(self)
		is_on_ice = (floor_type == "ICE")
	else:
		is_on_ice = false

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

	# --- S2: 냉동 게이지 업데이트 ---
	update_freeze_gauge(delta)
	
	# --- 냉동 게이지 1초마다 출력 ---
	_print_timer += delta
	if _print_timer >= PRINT_INTERVAL:
		print("냉동 게이지:", current_freeze_gauge, "/", max_freeze_gauge)
		_print_timer = 0.0

	# --- S3: 쉐이더 업데이트 ---
	if background and background.material and not get_node("/root/TitleMap/GameManager").is_darkness_active:
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
	bullet.owner_node = self
	bullet.global_position = fire_point.global_position
	bullet.global_rotation = cannon_pivot.global_rotation
	bullet.linear_velocity = bullet.transform.x * power

# 쿨다운 타이머 함수 (S3)
func _on_cooldown_timer_timeout():
	can_fire = true
	setup_bar_for_charging()

# 데미지 및 충돌 함수 (S3)
func take_damage(amount):
	hp -= amount
	var tween = create_tween().set_loops(2)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		emit_signal("game_over")
		queue_free()

func _on_hitbox_body_entered(body):
	if body.is_in_group("bullets"):
		take_damage(10)
		if body.has_method("explode"):
			body.explode()
		else:
			body.queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("stalactites") and area.is_falling:
		take_damage(20)

# --- 냉동 게이지 함수 (S2) ---
func update_freeze_gauge(delta: float):
	var previous_gauge = current_freeze_gauge

	if is_warming_up:
		# 온열장치 범위 안에 있을 때: 빠르게 게이지 감소
		current_freeze_gauge = max(current_freeze_gauge - warm_rate * delta, 0.0)
	elif is_on_ice:
		# 얼음 위에 있을 때: 게이지 증가
		current_freeze_gauge = min(current_freeze_gauge + freeze_rate * delta, max_freeze_gauge)
	else:
		# 얼음 위가 아닐 때: 서서히 게이지 감소
		current_freeze_gauge = max(current_freeze_gauge - (warm_rate / 2.0) * delta, 0.0)



	if current_freeze_gauge >= max_freeze_gauge and not is_frozen:
		is_frozen = true
		apply_freeze_debuff(true)
	elif current_freeze_gauge < max_freeze_gauge and is_frozen: # 게이지가 최대치 미만으로 내려가면 해동
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
